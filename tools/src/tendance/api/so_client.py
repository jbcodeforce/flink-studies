#!/usr/bin/env python3
"""
Stack Overflow API Client for Tendance

This module provides a comprehensive client for interacting with the Stack Exchange API,
specifically designed for retrieving questions related to Apache Flink and other subjects.
"""

import time
import logging
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any, Iterator, Tuple
from pathlib import Path
import json
from functools import wraps

from stackapi import StackAPI

from .models import (
    Question,
    Answer,
    QuestionsResponse,
    AnswersResponse,
    QueryFilters,
    RateLimitInfo,
    ClientConfig,
    QuestionSort,
    SortOrder,
)

# Configure logging
logger = logging.getLogger(__name__)


class StackExchangeError(Exception):
    """Base exception for Stack Exchange API errors"""
    pass


class RateLimitError(StackExchangeError):
    """Exception raised when API rate limit is exceeded"""
    
    def __init__(self, message: str, backoff_seconds: Optional[int] = None):
        super().__init__(message)
        self.backoff_seconds = backoff_seconds


class QuotaExhaustedError(StackExchangeError):
    """Exception raised when API quota is exhausted"""
    pass


def retry_on_rate_limit(max_retries: int = 3, backoff_factor: float = 1.0):
    """Decorator to retry function on rate limit errors"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except RateLimitError as e:
                    if attempt == max_retries - 1:
                        raise
                    
                    wait_time = (backoff_factor * (2 ** attempt)) + (e.backoff_seconds or 1)
                    logger.warning(f"Rate limit hit, waiting {wait_time}s before retry {attempt + 1}/{max_retries}")
                    time.sleep(wait_time)
                    
            return func(*args, **kwargs)  # Final attempt
        return wrapper
    return decorator


class StackOverflowClient:
    """Comprehensive Stack Overflow API client with Apache Flink focus"""
    
    def __init__(self, config: Optional[ClientConfig] = None):
        """Initialize the Stack Overflow client
        
        Args:
            config: Client configuration, defaults to basic config if None
        """
        self.config = config or ClientConfig()
        self._api = None
        self._cache = {}
        self._rate_limit_info: Optional[RateLimitInfo] = None
        
        # Initialize the StackAPI client
        self._init_api_client()
        
        logger.info(f"StackOverflow client initialized for site: {self.config.site}")
    
    def _init_api_client(self):
        """Initialize the StackAPI client with configuration"""
        try:
            # Initialize StackAPI with minimal configuration
            # We'll handle pagination manually to avoid issues with StackAPI's internal state
            self._api = StackAPI(
                name=self.config.site,
                key=self.config.api_key,
                max_pages=1,  # Set to 1 and handle pagination manually
            )
            
            logger.info(f"StackAPI initialized for site: {self.config.site}")
            
        except Exception as e:
            raise StackExchangeError(f"Failed to initialize Stack API client: {e}")
    
    def _handle_api_response(self, response: Dict[str, Any]) -> Dict[str, Any]:
        """Handle API response and extract rate limit information"""
        # Update rate limit info
        if 'quota_max' in response and 'quota_remaining' in response:
            self._rate_limit_info = RateLimitInfo(
                quota_max=response.get('quota_max', 0),
                quota_remaining=response.get('quota_remaining', 0),
                backoff_seconds=response.get('backoff', None)
            )
            
            # Check if quota is low
            if self._rate_limit_info.quota_remaining < 100:
                logger.warning(
                    f"API quota running low: {self._rate_limit_info.quota_remaining}/{self._rate_limit_info.quota_max} remaining"
                )
        
        # Handle API errors
        if 'error_id' in response:
            error_msg = response.get('error_message', 'Unknown API error')
            error_id = response.get('error_id')
            
            if error_id == 502:  # Throttle violation
                backoff = response.get('backoff', 1)
                raise RateLimitError(f"Rate limit exceeded: {error_msg}", backoff)
            elif error_id == 400:  # Bad parameter
                raise StackExchangeError(f"Bad request: {error_msg}")
            else:
                raise StackExchangeError(f"API error {error_id}: {error_msg}")
        
        return response
    
    @retry_on_rate_limit(max_retries=3, backoff_factor=1.5)
    def get_questions(
        self,
        filters: Optional[QueryFilters] = None,
        include_body: bool = False
    ) -> QuestionsResponse:
        """Retrieve questions based on filters
        
        Args:
            filters: Query filters for filtering questions
            include_body: Whether to include question body content
            
        Returns:
            QuestionsResponse containing questions and metadata
            
        Raises:
            StackExchangeError: If API request fails
            RateLimitError: If rate limit is exceeded
        """
        if not filters:
            filters = QueryFilters()
        
        try:
            # Prepare API parameters
            params = {
                'order': filters.order.value,
                'sort': filters.sort.value,
                'page': filters.page,
                'pagesize': filters.page_size,
                'filter': '!nKzQUR3Egv' if include_body else 'default'  # Include body if requested
            }
            
            # Add tag filtering
            if filters.tags:
                params['tagged'] = ';'.join(filters.tags)
            
            # Add date filtering
            if filters.from_date:
                params['fromdate'] = int(filters.from_date.timestamp())
            if filters.to_date:
                params['todate'] = int(filters.to_date.timestamp())
            
            # Add score filtering
            if filters.min_score is not None:
                params['min'] = filters.min_score
            
            logger.info(f"Fetching questions with params: {params}")
            
            # Make API request
            response = self._api.fetch('questions', **params)
            response = self._handle_api_response(response)
            
            # Parse questions
            questions = []
            for item in response.get('items', []):
                try:
                    question = Question(**item)
                    questions.append(question)
                except Exception as e:
                    logger.warning(f"Failed to parse question {item.get('question_id', 'unknown')}: {e}")
            
            return QuestionsResponse(
                questions=questions,
                has_more=response.get('has_more', False),
                quota_max=response.get('quota_max', 0),
                quota_remaining=response.get('quota_remaining', 0),
                page=filters.page,
                page_size=filters.page_size,
                total_questions=len(questions)
            )
            
        except RateLimitError:
            raise
        except Exception as e:
            logger.error(f"Error fetching questions: {e}")
            raise StackExchangeError(f"Failed to fetch questions: {e}")
    
    def get_questions_by_apache_flink(
        self,
        from_date: Optional[datetime] = None,
        to_date: Optional[datetime] = None,
        min_score: int = 0,
        page_size: int = 50
    ) -> Iterator[QuestionsResponse]:
        """Get questions related to Apache Flink with pagination
        
        Args:
            from_date: Start date for filtering
            to_date: End date for filtering
            min_score: Minimum score threshold
            page_size: Number of questions per page
            
        Yields:
            QuestionsResponse for each page of results
        """
        # Apache Flink related tags
        flink_tags = ['apache-flink', 'flink-sql', 'flink-streaming', 'flink-cep']
        
        filters = QueryFilters(
            tags=flink_tags,
            from_date=from_date,
            to_date=to_date,
            min_score=min_score,
            page_size=page_size,
            sort=QuestionSort.CREATION,
            order=SortOrder.DESC
        )
        
        page = 1
        while True:
            filters.page = page
            response = self.get_questions(filters, include_body=True)
            
            if not response.questions:
                break
                
            logger.info(f"Retrieved {len(response.questions)} Apache Flink questions from page {page}")
            yield response
            
            if not response.has_more:
                break
                
            page += 1
    
    def get_question_answers(self, question_id: int) -> AnswersResponse:
        """Get answers for a specific question
        
        Args:
            question_id: The question ID to get answers for
            
        Returns:
            AnswersResponse containing answers
        """
        try:
            response = self._api.fetch(f'questions/{question_id}/answers', 
                                     order='desc', 
                                     sort='votes',
                                     filter='withbody')  # Include body content for answers
            response = self._handle_api_response(response)
            
            answers = []
            for item in response.get('items', []):
                try:
                    answer = Answer(**item)
                    answers.append(answer)
                except Exception as e:
                    logger.warning(f"Failed to parse answer {item.get('answer_id', 'unknown')}: {e}")
            
            return AnswersResponse(
                answers=answers,
                has_more=response.get('has_more', False),
                quota_max=response.get('quota_max', 0),
                quota_remaining=response.get('quota_remaining', 0)
            )
            
        except Exception as e:
            logger.error(f"Error fetching answers for question {question_id}: {e}")
            raise StackExchangeError(f"Failed to fetch answers: {e}")
    
    @retry_on_rate_limit(max_retries=3, backoff_factor=1.5)
    def get_questions_with_answers(
        self,
        questions: List[Question],
        max_answers_per_question: int = 3
    ) -> Dict[int, List[Answer]]:
        """Get answers for multiple questions efficiently
        
        Args:
            questions: List of questions to get answers for
            max_answers_per_question: Maximum number of answers to retrieve per question
            
        Returns:
            Dictionary mapping question_id to list of answers
        """
        question_answers = {}
        
        for question in questions:
            logger.info(f"Processing question {question.question_id}: is_answered={question.is_answered}, answer_count={question.answer_count}")
            
            if not question.is_answered or question.answer_count == 0:
                question_answers[question.question_id] = []
                continue
                
            try:
                logger.info(f"Fetching answers for question {question.question_id}")
                answers_response = self.get_question_answers(question.question_id)
                
                # Limit number of answers
                answers = answers_response.answers[:max_answers_per_question]
                question_answers[question.question_id] = answers
                
                logger.info(f"Retrieved {len(answers)} answers for question {question.question_id} (scores: {[a.score for a in answers]})")
                
            except Exception as e:
                logger.warning(f"Failed to get answers for question {question.question_id}: {e}")
                question_answers[question.question_id] = []
        
        return question_answers
    
    def extract_rag_knowledge(
        self,
        questions: List[Question],
        include_code: bool = True,
        max_answer_length: int = 5000,
        min_answer_score: int = 0,
        max_answers_per_question: int = 3
    ) -> List:
        """Extract RAG-suitable knowledge from questions and their answers
        
        Args:
            questions: List of questions to process
            include_code: Whether to include code blocks in extracted content
            max_answer_length: Maximum length of answer content
            min_answer_score: Minimum score for answers to be included  
            max_answers_per_question: Maximum answers to fetch per question
            
        Returns:
            List of knowledge entries suitable for RAG
        """
        # Import here to avoid circular imports
        from ..extractors import RAGContentExtractor
        
        # Get answers for all questions
        logger.info(f"Fetching answers for {len(questions)} questions...")
        question_answers = self.get_questions_with_answers(
            questions, 
            max_answers_per_question
        )
        
        # Initialize RAG extractor
        extractor = RAGContentExtractor(
            include_code=include_code,
            max_answer_length=max_answer_length,
            min_answer_score=min_answer_score
        )
        
        # Extract knowledge entries
        all_entries = []
        questions_with_answers = 0
        
        for question in questions:
            answers = question_answers.get(question.question_id, [])
            if answers:
                entries = extractor.extract_from_question_answers(question, answers)
                all_entries.extend(entries)
                if entries:
                    questions_with_answers += 1
        
        logger.info(f"Extracted {len(all_entries)} knowledge entries from {questions_with_answers} questions")
        return all_entries
    
    def search_questions(
        self,
        query: str,
        tags: Optional[List[str]] = None,
        from_date: Optional[datetime] = None,
        to_date: Optional[datetime] = None
    ) -> QuestionsResponse:
        """Search questions by title and body content
        
        Args:
            query: Search query string
            tags: Optional tags to filter by
            from_date: Start date for filtering
            to_date: End date for filtering
            
        Returns:
            QuestionsResponse containing matching questions
        """
        try:
            params = {
                'order': 'desc',
                'sort': 'relevance',
                'q': query,
                'pagesize': 50
            }
            
            if tags:
                params['tagged'] = ';'.join(tags)
            if from_date:
                params['fromdate'] = int(from_date.timestamp())
            if to_date:
                params['todate'] = int(to_date.timestamp())
            
            response = self._api.fetch('search', **params)
            response = self._handle_api_response(response)
            
            questions = []
            for item in response.get('items', []):
                try:
                    question = Question(**item)
                    questions.append(question)
                except Exception as e:
                    logger.warning(f"Failed to parse question {item.get('question_id', 'unknown')}: {e}")
            
            return QuestionsResponse(
                questions=questions,
                has_more=response.get('has_more', False),
                quota_max=response.get('quota_max', 0),
                quota_remaining=response.get('quota_remaining', 0)
            )
            
        except Exception as e:
            logger.error(f"Error searching questions: {e}")
            raise StackExchangeError(f"Failed to search questions: {e}")
    
    def get_rate_limit_info(self) -> Optional[RateLimitInfo]:
        """Get current rate limit information"""
        return self._rate_limit_info
    
    def save_questions_to_file(self, questions: List[Question], file_path: Path):
        """Save questions to a JSON file
        
        Args:
            questions: List of questions to save
            file_path: Path to save the JSON file
        """
        try:
            # Convert questions to dict format for JSON serialization
            questions_data = [
                question.model_dump(by_alias=True, exclude_none=True)
                for question in questions
            ]
            
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(questions_data, f, indent=2, ensure_ascii=False, default=str)
            
            logger.info(f"Saved {len(questions)} questions to {file_path}")
            
        except Exception as e:
            logger.error(f"Error saving questions to file: {e}")
            raise StackExchangeError(f"Failed to save questions: {e}")
    
    def load_questions_from_file(self, file_path: Path) -> List[Question]:
        """Load questions from a JSON file
        
        Args:
            file_path: Path to the JSON file
            
        Returns:
            List of Question objects
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                questions_data = json.load(f)
            
            questions = []
            for item in questions_data:
                try:
                    question = Question(**item)
                    questions.append(question)
                except Exception as e:
                    logger.warning(f"Failed to parse saved question: {e}")
            
            logger.info(f"Loaded {len(questions)} questions from {file_path}")
            return questions
            
        except FileNotFoundError:
            logger.warning(f"Questions file not found: {file_path}")
            return []
        except Exception as e:
            logger.error(f"Error loading questions from file: {e}")
            raise StackExchangeError(f"Failed to load questions: {e}")
    
    def get_question_statistics(self, questions: List[Question]) -> Dict[str, Any]:
        """Generate statistics for a list of questions
        
        Args:
            questions: List of questions to analyze
            
        Returns:
            Dictionary containing various statistics
        """
        if not questions:
            return {}
        
        # Basic counts
        total_questions = len(questions)
        answered_questions = sum(1 for q in questions if q.is_answered)
        accepted_answers = sum(1 for q in questions if q.accepted_answer_id is not None)
        
        # Score statistics
        scores = [q.score for q in questions]
        avg_score = sum(scores) / len(scores) if scores else 0
        max_score = max(scores) if scores else 0
        min_score = min(scores) if scores else 0
        
        # View statistics
        views = [q.view_count for q in questions]
        total_views = sum(views)
        avg_views = total_views / len(views) if views else 0
        
        # Tag analysis
        tag_counts = {}
        for question in questions:
            for tag in question.tags:
                tag_counts[tag] = tag_counts.get(tag, 0) + 1
        
        # Sort tags by frequency
        top_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)[:10]
        
        # Date analysis
        creation_dates = [q.creation_date for q in questions if q.creation_date]
        date_range = None
        if creation_dates:
            min_date = min(creation_dates)
            max_date = max(creation_dates)
            date_range = {
                'earliest': min_date.isoformat(),
                'latest': max_date.isoformat(),
                'span_days': (max_date - min_date).days
            }
        
        return {
            'total_questions': total_questions,
            'answered_questions': answered_questions,
            'accepted_answers': accepted_answers,
            'answer_rate': answered_questions / total_questions if total_questions > 0 else 0,
            'acceptance_rate': accepted_answers / total_questions if total_questions > 0 else 0,
            'score_statistics': {
                'average': round(avg_score, 2),
                'maximum': max_score,
                'minimum': min_score
            },
            'view_statistics': {
                'total': total_views,
                'average': round(avg_views, 2)
            },
            'top_tags': top_tags,
            'date_range': date_range
        }
