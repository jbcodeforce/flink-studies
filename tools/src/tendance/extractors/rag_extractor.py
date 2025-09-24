#!/usr/bin/env python3
"""
RAG Content Extractor for Tendance

This module extracts structured knowledge from Stack Exchange questions and answers
for use in Retrieval Augmented Generation (RAG) systems.
"""

import re
import logging
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime
from dataclasses import dataclass

from bs4 import BeautifulSoup
from pydantic import BaseModel, Field

from ..api.models import Question, Answer

logger = logging.getLogger(__name__)


@dataclass
class KnowledgeEntry:
    """A knowledge entry suitable for RAG systems"""
    id: str
    title: str
    question: str
    answer: str
    tags: List[str]
    score: int
    is_accepted: bool
    created_date: datetime
    source_url: str
    metadata: Dict[str, Any]


class RAGContentExtractor:
    """Extract and format content for RAG systems"""
    
    def __init__(self, include_code: bool = True, max_answer_length: int = 5000, min_answer_score: int = 0):
        """Initialize the RAG content extractor
        
        Args:
            include_code: Whether to include code blocks in extracted content
            max_answer_length: Maximum length of answer content (characters)
            min_answer_score: Minimum score for answers to be included
        """
        self.include_code = include_code
        self.max_answer_length = max_answer_length
        self.min_answer_score = min_answer_score
    
    def clean_html_content(self, html_content: str) -> str:
        """Clean HTML content to plain text while preserving structure
        
        Args:
            html_content: Raw HTML content
            
        Returns:
            Cleaned plain text content
        """
        if not html_content:
            return ""
        
        # Parse HTML
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Handle code blocks
        code_blocks = soup.find_all(['code', 'pre'])
        if self.include_code:
            for block in code_blocks:
                # Wrap code in markdown-style backticks
                if block.name == 'pre':
                    block.string = f"\n```\n{block.get_text()}\n```\n"
                else:
                    block.string = f"`{block.get_text()}`"
        else:
            # Remove code blocks entirely
            for block in code_blocks:
                block.decompose()
        
        # Convert common HTML elements to markdown-like format
        for strong in soup.find_all(['strong', 'b']):
            strong.string = f"**{strong.get_text()}**"
        
        for em in soup.find_all(['em', 'i']):
            em.string = f"*{em.get_text()}*"
        
        # Handle links
        for link in soup.find_all('a'):
            href = link.get('href', '')
            text = link.get_text()
            if href and text:
                link.string = f"[{text}]({href})"
            else:
                link.string = text
        
        # Handle lists
        for ul in soup.find_all('ul'):
            items = ul.find_all('li')
            list_text = '\n'.join([f"- {li.get_text().strip()}" for li in items])
            ul.string = f"\n{list_text}\n"
        
        for ol in soup.find_all('ol'):
            items = ol.find_all('li')
            list_text = '\n'.join([f"{i+1}. {li.get_text().strip()}" for i, li in enumerate(items)])
            ol.string = f"\n{list_text}\n"
        
        # Get clean text
        clean_text = soup.get_text()
        
        # Clean up whitespace
        clean_text = re.sub(r'\n\s*\n\s*\n', '\n\n', clean_text)  # Remove excessive line breaks
        clean_text = re.sub(r'[ \t]+', ' ', clean_text)  # Normalize spaces
        clean_text = clean_text.strip()
        
        return clean_text
    
    def extract_knowledge_entry(self, question: Question, answer: Answer) -> KnowledgeEntry:
        """Extract a knowledge entry from a question-answer pair
        
        Args:
            question: Question object
            answer: Answer object
            
        Returns:
            KnowledgeEntry suitable for RAG
        """
        # Clean content
        question_text = self.clean_html_content(question.body or "")
        answer_text = self.clean_html_content(answer.body or "")
        
        # Truncate answer if too long
        if len(answer_text) > self.max_answer_length:
            answer_text = answer_text[:self.max_answer_length] + "... [content truncated]"
        
        # Create unique ID
        entry_id = f"q{question.question_id}_a{answer.answer_id}"
        
        # Build metadata
        metadata = {
            'question_id': question.question_id,
            'answer_id': answer.answer_id,
            'question_score': question.score,
            'answer_score': answer.score,
            'view_count': question.view_count,
            'answer_count': question.answer_count,
            'question_owner': question.owner.display_name if question.owner else None,
            'answer_owner': answer.owner.display_name if answer.owner else None,
            'last_activity': question.last_activity_date.isoformat(),
            'created_date': answer.creation_date.isoformat(),
        }
        
        return KnowledgeEntry(
            id=entry_id,
            title=question.title,
            question=question_text,
            answer=answer_text,
            tags=question.tags,
            score=answer.score,
            is_accepted=answer.is_accepted,
            created_date=answer.creation_date,
            source_url=question.link,
            metadata=metadata
        )
    
    def filter_answers(self, answers: List[Answer]) -> List[Answer]:
        """Filter answers based on quality criteria
        
        Args:
            answers: List of answers to filter
            
        Returns:
            Filtered list of high-quality answers
        """
        # Sort by score (descending), then by acceptance
        sorted_answers = sorted(
            answers, 
            key=lambda a: (a.is_accepted, a.score), 
            reverse=True
        )
        
        logger.debug(f"Sorting {len(answers)} answers, scores: {[a.score for a in sorted_answers]}")
        
        # Filter by minimum score
        quality_answers = []
        for answer in sorted_answers:
            has_content = bool(answer.body or answer.body_markdown)
            meets_score = answer.score >= self.min_answer_score
            
            logger.debug(f"Answer {answer.answer_id}: score={answer.score} (min={self.min_answer_score}), has_content={has_content}, accepted={answer.is_accepted}")
            
            if meets_score and has_content:
                quality_answers.append(answer)
        
        logger.info(f"Filtered {len(answers)} answers -> {len(quality_answers)} quality answers")
        return quality_answers
    
    def extract_from_question_answers(self, question: Question, answers: List[Answer]) -> List[KnowledgeEntry]:
        """Extract knowledge entries from a question and its answers
        
        Args:
            question: Question object
            answers: List of answer objects
            
        Returns:
            List of knowledge entries
        """
        if not question.body and not question.body_markdown:
            logger.debug(f"Skipping question {question.question_id} - no body content")
            return []
        
        # Filter answers for quality
        quality_answers = self.filter_answers(answers)
        
        logger.info(f"Question {question.question_id}: {len(answers)} total answers, {len(quality_answers)} quality answers")
        
        if not quality_answers:
            logger.debug(f"No quality answers found for question {question.question_id}")
            return []
        
        # Extract entries
        entries = []
        for answer in quality_answers:
            try:
                entry = self.extract_knowledge_entry(question, answer)
                entries.append(entry)
                logger.debug(f"Extracted knowledge entry: {entry.id}")
            except Exception as e:
                logger.warning(f"Failed to extract entry for Q{question.question_id}/A{answer.answer_id}: {e}")
        
        return entries
    
    def save_as_jsonl(self, entries: List[KnowledgeEntry], file_path: Path) -> None:
        """Save knowledge entries as JSON Lines format
        
        Args:
            entries: List of knowledge entries
            file_path: Output file path
        """
        import json
        
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            for entry in entries:
                # Convert dataclass to dict
                entry_dict = {
                    'id': entry.id,
                    'title': entry.title,
                    'question': entry.question,
                    'answer': entry.answer,
                    'tags': entry.tags,
                    'score': entry.score,
                    'is_accepted': entry.is_accepted,
                    'created_date': entry.created_date.isoformat(),
                    'source_url': entry.source_url,
                    'metadata': entry.metadata
                }
                json.dump(entry_dict, f, ensure_ascii=False)
                f.write('\n')
        
        logger.info(f"Saved {len(entries)} knowledge entries to {file_path}")
    
    def save_as_text(self, entries: List[KnowledgeEntry], file_path: Path) -> None:
        """Save knowledge entries as structured text format
        
        Args:
            entries: List of knowledge entries
            file_path: Output file path
        """
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write("# Stack Exchange Knowledge Base\n\n")
            f.write(f"Extracted: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Entries: {len(entries)}\n\n")
            f.write("---\n\n")
            
            for i, entry in enumerate(entries, 1):
                f.write(f"## Entry {i}: {entry.title}\n\n")
                f.write(f"**ID**: {entry.id}\n")
                f.write(f"**Tags**: {', '.join(entry.tags)}\n")
                f.write(f"**Score**: {entry.score} {'✓ Accepted' if entry.is_accepted else ''}\n")
                f.write(f"**Created**: {entry.created_date.strftime('%Y-%m-%d')}\n")
                f.write(f"**Source**: {entry.source_url}\n\n")
                
                f.write("### Question\n\n")
                f.write(f"{entry.question}\n\n")
                
                f.write("### Answer\n\n")
                f.write(f"{entry.answer}\n\n")
                
                f.write("---\n\n")
        
        logger.info(f"Saved {len(entries)} knowledge entries to {file_path}")
    
    def save_as_markdown(self, entries: List[KnowledgeEntry], file_path: Path) -> None:
        """Save knowledge entries as structured markdown format
        
        Args:
            entries: List of knowledge entries
            file_path: Output file path
        """
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write("# Stack Exchange Knowledge Base\n\n")
            f.write(f"> Extracted: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  \n")
            f.write(f"> Total Entries: {len(entries)}\n\n")
            
            # Table of contents
            f.write("## Table of Contents\n\n")
            for i, entry in enumerate(entries, 1):
                anchor = entry.title.lower().replace(' ', '-').replace('/', '').replace('?', '')
                f.write(f"{i}. [{entry.title}](#{anchor})\n")
            f.write("\n---\n\n")
            
            for i, entry in enumerate(entries, 1):
                anchor = entry.title.lower().replace(' ', '-').replace('/', '').replace('?', '')
                f.write(f"## {i}. {entry.title} {{#{anchor}}}\n\n")
                
                f.write(f"- **Entry ID**: `{entry.id}`\n")
                f.write(f"- **Tags**: {', '.join([f'`{tag}`' for tag in entry.tags])}\n")
                f.write(f"- **Score**: {entry.score} {'🏆 **Accepted Answer**' if entry.is_accepted else ''}\n")
                f.write(f"- **Created**: {entry.created_date.strftime('%Y-%m-%d')}\n")
                f.write(f"- **Source**: [{entry.source_url}]({entry.source_url})\n\n")
                
                f.write("### Question\n\n")
                f.write(f"{entry.question}\n\n")
                
                f.write("### Answer\n\n")
                f.write(f"{entry.answer}\n\n")
                
                f.write("---\n\n")
        
        logger.info(f"Saved {len(entries)} knowledge entries to {file_path}")
    
    def get_statistics(self, entries: List[KnowledgeEntry]) -> Dict[str, Any]:
        """Get statistics about extracted knowledge entries
        
        Args:
            entries: List of knowledge entries
            
        Returns:
            Statistics dictionary
        """
        if not entries:
            return {}
        
        total_entries = len(entries)
        accepted_entries = sum(1 for e in entries if e.is_accepted)
        avg_score = sum(e.score for e in entries) / total_entries
        
        # Tag frequency
        tag_counts = {}
        for entry in entries:
            for tag in entry.tags:
                tag_counts[tag] = tag_counts.get(tag, 0) + 1
        
        top_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)[:10]
        
        # Score distribution
        score_ranges = {'negative': 0, '0-5': 0, '6-20': 0, '21-50': 0, '50+': 0}
        for entry in entries:
            if entry.score < 0:
                score_ranges['negative'] += 1
            elif entry.score <= 5:
                score_ranges['0-5'] += 1
            elif entry.score <= 20:
                score_ranges['6-20'] += 1
            elif entry.score <= 50:
                score_ranges['21-50'] += 1
            else:
                score_ranges['50+'] += 1
        
        return {
            'total_entries': total_entries,
            'accepted_answers': accepted_entries,
            'acceptance_rate': accepted_entries / total_entries * 100,
            'average_score': avg_score,
            'top_tags': top_tags,
            'score_distribution': score_ranges,
            'date_range': {
                'earliest': min(e.created_date for e in entries),
                'latest': max(e.created_date for e in entries),
            }
        }
