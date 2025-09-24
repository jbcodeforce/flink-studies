#!/usr/bin/env python3
"""
Stack Overflow Client Demo Script

This script demonstrates how to use the Tendance Stack Overflow API client
to retrieve Apache Flink questions from Stack Overflow.
"""

import asyncio
from datetime import datetime, timedelta
from pathlib import Path

from tendance.api import StackOverflowClient, QueryFilters, ClientConfig, QuestionSort, SortOrder


async def demo_basic_usage():
    """Demonstrate basic Stack Overflow client usage"""
    print("🚀 Tendance Stack Overflow Client Demo")
    print("=" * 50)
    
    # Initialize client (API key is optional but recommended for higher rate limits)
    config = ClientConfig(
        site="stackoverflow",
        # api_key="your_api_key_here",  # Uncomment and add your API key
        timeout_seconds=30
    )
    
    client = StackOverflowClient(config)
    
    print("✅ Client initialized successfully!")
    print()
    
    # Demo 1: Get recent Apache Flink questions
    print("📋 Demo 1: Recent Apache Flink Questions")
    print("-" * 40)
    
    filters = QueryFilters(
        tags=['apache-flink'],
        from_date=datetime.now() - timedelta(days=30),  # Last 30 days
        sort=QuestionSort.CREATION,
        order=SortOrder.DESC,
        page_size=5
    )
    
    try:
        response = client.get_questions(filters, include_body=True)
        
        print(f"Found {len(response.questions)} recent questions:")
        for i, question in enumerate(response.questions, 1):
            print(f"  {i}. {question.title}")
            print(f"     Score: {question.score}, Views: {question.view_count}")
            print(f"     Tags: {', '.join(question.tags)}")
            print(f"     Link: {question.link}")
            print()
        
        # Show rate limit info
        rate_limit = client.get_rate_limit_info()
        if rate_limit:
            print(f"📊 Rate limit: {rate_limit.quota_remaining}/{rate_limit.quota_max} requests remaining")
        print()
        
    except Exception as e:
        print(f"❌ Error fetching questions: {e}")
        print()
    
    # Demo 2: Search for specific topics
    print("🔍 Demo 2: Search for Flink State Management")
    print("-" * 45)
    
    try:
        search_response = client.search_questions(
            query="state management",
            tags=['apache-flink'],
            from_date=datetime.now() - timedelta(days=90)
        )
        
        print(f"Found {len(search_response.questions)} questions about state management:")
        for i, question in enumerate(search_response.questions[:3], 1):  # Show top 3
            print(f"  {i}. {question.title}")
            print(f"     Score: {question.score}, Answered: {question.is_answered}")
            print(f"     Link: {question.link}")
            print()
        
    except Exception as e:
        print(f"❌ Error searching questions: {e}")
        print()
    
    # Demo 3: Get Apache Flink questions with pagination
    print("📄 Demo 3: Apache Flink Questions with Pagination")
    print("-" * 50)
    
    try:
        print("Fetching Apache Flink questions (max 2 pages)...")
        all_questions = []
        page_count = 0
        
        for response in client.get_questions_by_apache_flink(
            from_date=datetime.now() - timedelta(days=60),
            min_score=0,
            page_size=10
        ):
            page_count += 1
            all_questions.extend(response.questions)
            print(f"  Page {page_count}: {len(response.questions)} questions")
            
            if page_count >= 2:  # Limit for demo
                break
        
        print(f"\n📈 Total questions collected: {len(all_questions)}")
        
        # Generate statistics
        if all_questions:
            stats = client.get_question_statistics(all_questions)
            print("\n📊 Statistics:")
            print(f"  • Total questions: {stats['total_questions']}")
            print(f"  • Answered: {stats['answered_questions']} ({stats['answer_rate']:.1%})")
            print(f"  • Average score: {stats['score_statistics']['average']}")
            print(f"  • Total views: {stats['view_statistics']['total']:,}")
            
            if stats['top_tags']:
                print(f"  • Top tags: {', '.join([f'{tag} ({count})' for tag, count in stats['top_tags'][:5]])}")
        
        # Save questions to file for later analysis
        output_dir = Path("./output")
        output_dir.mkdir(exist_ok=True)
        
        if all_questions:
            output_file = output_dir / f"apache_flink_questions_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            client.save_questions_to_file(all_questions, output_file)
            print(f"\n💾 Saved questions to: {output_file}")
        
    except Exception as e:
        print(f"❌ Error in pagination demo: {e}")
        print()
    
    # Demo 4: Get answers for a specific question (if we have questions)
    if all_questions:
        print("\n💬 Demo 4: Get Answers for Top Question")
        print("-" * 40)
        
        # Get the highest scored question
        top_question = max(all_questions, key=lambda q: q.score)
        
        try:
            answers = client.get_question_answers(top_question.question_id)
            
            print(f"Question: {top_question.title}")
            print(f"Found {len(answers.answers)} answers:")
            
            for i, answer in enumerate(answers.answers[:3], 1):  # Show top 3 answers
                status = "✅ Accepted" if answer.is_accepted else f"Score: {answer.score}"
                print(f"  {i}. {status}")
                print(f"     Created: {answer.creation_date.strftime('%Y-%m-%d')}")
                
        except Exception as e:
            print(f"❌ Error fetching answers: {e}")
    
    print("\n🎉 Demo completed!")
    print(f"💡 Tip: Get a Stack Exchange API key at https://stackapps.com/apps/oauth/register")
    print(f"    to increase your rate limit from 300 to 10,000 requests per day!")


if __name__ == "__main__":
    asyncio.run(demo_basic_usage())
