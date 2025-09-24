#!/usr/bin/env python3
"""
Unit tests for Stack Overflow API Client
"""

import pytest
import json
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
from typing import Dict, Any

from tendance.api import (
    StackOverflowClient,
    StackExchangeError,
    RateLimitError,
    QuotaExhaustedError,
    Question,
    QueryFilters,
    QuestionsResponse,
    ClientConfig,
    RateLimitInfo,
    QuestionSort,
    SortOrder,
)
from tendance.api.so_client import retry_on_rate_limit


class TestStackOverflowClient:
    """Test class for Stack Overflow client"""
    
    def setup_method(self):
        """Set up test client for each test"""
        self.config = ClientConfig(
            api_key="test_key",
            site="stackoverflow",
            max_retries=1,
            timeout_seconds=10
        )
        
    @patch('tendance.api.so_client.StackAPI')
    def test_client_initialization(self, mock_stackapi):
        """Test client initialization"""
        client = StackOverflowClient(self.config)
        
        assert client.config == self.config
        mock_stackapi.assert_called_once()
        
    @patch('tendance.api.so_client.StackAPI')
    def test_client_initialization_no_config(self, mock_stackapi):
        """Test client initialization with default config"""
        client = StackOverflowClient()
        
        assert client.config is not None
        assert client.config.site == "stackoverflow"
        
    @patch('tendance.api.so_client.StackAPI')
    def test_api_initialization_error(self, mock_stackapi):
        """Test error handling during API initialization"""
        mock_stackapi.side_effect = Exception("API initialization failed")
        
        with pytest.raises(StackExchangeError, match="Failed to initialize Stack API client"):
            StackOverflowClient(self.config)
    
    def test_handle_api_response_success(self):
        """Test successful API response handling"""
        with patch('tendance.api.so_client.StackAPI'):
            client = StackOverflowClient(self.config)
            
            response = {
                'items': [{'question_id': 1, 'title': 'Test'}],
                'quota_max': 10000,
                'quota_remaining': 9999,
                'has_more': False
            }
            
            result = client._handle_api_response(response)
            
            assert result == response
            assert client._rate_limit_info is not None
            assert client._rate_limit_info.quota_max == 10000
            assert client._rate_limit_info.quota_remaining == 9999
    
    def test_handle_api_response_rate_limit_error(self):
        """Test rate limit error handling"""
        with patch('tendance.api.so_client.StackAPI'):
            client = StackOverflowClient(self.config)
            
            response = {
                'error_id': 502,
                'error_message': 'Throttle violation',
                'backoff': 5
            }
            
            with pytest.raises(RateLimitError, match="Rate limit exceeded"):
                client._handle_api_response(response)
    
    def test_handle_api_response_general_error(self):
        """Test general API error handling"""
        with patch('tendance.api.so_client.StackAPI'):
            client = StackOverflowClient(self.config)
            
            response = {
                'error_id': 400,
                'error_message': 'Bad parameter'
            }
            
            with pytest.raises(StackExchangeError, match="Bad request"):
                client._handle_api_response(response)

    @patch('tendance.api.so_client.StackAPI')
    def test_get_questions_basic(self, mock_stackapi):
        """Test basic question retrieval"""
        # Mock API response
        mock_api_instance = Mock()
        mock_stackapi.return_value = mock_api_instance
        
        mock_response = {
            'items': [
                {
                    'question_id': 12345,
                    'title': 'How to use Apache Flink?',
                    'link': 'https://stackoverflow.com/questions/12345',
                    'tags': ['apache-flink', 'java'],
                    'creation_date': int(datetime.now().timestamp()),
                    'last_activity_date': int(datetime.now().timestamp()),
                    'score': 5,
                    'view_count': 100,
                    'answer_count': 2,
                    'is_answered': True
                }
            ],
            'has_more': False,
            'quota_max': 10000,
            'quota_remaining': 9999
        }
        
        mock_api_instance.fetch.return_value = mock_response
        
        client = StackOverflowClient(self.config)
        filters = QueryFilters(tags=['apache-flink'])
        
        response = client.get_questions(filters)
        
        assert isinstance(response, QuestionsResponse)
        assert len(response.questions) == 1
        assert response.questions[0].question_id == 12345
        assert response.questions[0].title == "How to use Apache Flink?"
        assert 'apache-flink' in response.questions[0].tags
        
        # Verify API was called with correct parameters
        mock_api_instance.fetch.assert_called_once()
        call_args = mock_api_instance.fetch.call_args
        assert call_args[0][0] == 'questions'
        assert call_args[1]['tagged'] == 'apache-flink'

    @patch('tendance.api.so_client.StackAPI')
    def test_get_questions_with_date_filter(self, mock_stackapi):
        """Test question retrieval with date filtering"""
        mock_api_instance = Mock()
        mock_stackapi.return_value = mock_api_instance
        mock_api_instance.fetch.return_value = {
            'items': [],
            'has_more': False,
            'quota_max': 10000,
            'quota_remaining': 9999
        }
        
        client = StackOverflowClient(self.config)
        
        from_date = datetime(2024, 1, 1)
        to_date = datetime(2024, 12, 31)
        
        filters = QueryFilters(
            tags=['apache-flink'],
            from_date=from_date,
            to_date=to_date,
            min_score=5
        )
        
        client.get_questions(filters)
        
        call_args = mock_api_instance.fetch.call_args[1]
        assert call_args['fromdate'] == int(from_date.timestamp())
        assert call_args['todate'] == int(to_date.timestamp())
        assert call_args['min'] == 5

    @patch('tendance.api.so_client.StackAPI')
    def test_get_questions_by_apache_flink(self, mock_stackapi):
        """Test Apache Flink specific question retrieval"""
        mock_api_instance = Mock()
        mock_stackapi.return_value = mock_api_instance
        
        # Mock first page response
        mock_response_page1 = {
            'items': [
                {
                    'question_id': 1,
                    'title': 'Flink SQL Question',
                    'link': 'https://stackoverflow.com/questions/1',
                    'tags': ['flink-sql'],
                    'creation_date': int(datetime.now().timestamp()),
                    'last_activity_date': int(datetime.now().timestamp()),
                    'score': 3,
                    'view_count': 50,
                    'answer_count': 1,
                    'is_answered': True
                }
            ],
            'has_more': True,
            'quota_max': 10000,
            'quota_remaining': 9998
        }
        
        # Mock second page response
        mock_response_page2 = {
            'items': [
                {
                    'question_id': 2,
                    'title': 'Flink Streaming Question',
                    'link': 'https://stackoverflow.com/questions/2',
                    'tags': ['flink-streaming'],
                    'creation_date': int(datetime.now().timestamp()),
                    'last_activity_date': int(datetime.now().timestamp()),
                    'score': 7,
                    'view_count': 200,
                    'answer_count': 3,
                    'is_answered': True
                }
            ],
            'has_more': False,
            'quota_max': 10000,
            'quota_remaining': 9997
        }
        
        mock_api_instance.fetch.side_effect = [mock_response_page1, mock_response_page2]
        
        client = StackOverflowClient(self.config)
        
        pages = list(client.get_questions_by_apache_flink(
            from_date=datetime(2024, 1, 1),
            min_score=0
        ))
        
        assert len(pages) == 2
        assert len(pages[0].questions) == 1
        assert len(pages[1].questions) == 1
        assert pages[0].questions[0].question_id == 1
        assert pages[1].questions[0].question_id == 2

    @patch('tendance.api.so_client.StackAPI')
    def test_get_question_answers(self, mock_stackapi):
        """Test retrieving answers for a question"""
        mock_api_instance = Mock()
        mock_stackapi.return_value = mock_api_instance
        
        mock_response = {
            'items': [
                {
                    'answer_id': 100,
                    'question_id': 12345,
                    'creation_date': int(datetime.now().timestamp()),
                    'last_activity_date': int(datetime.now().timestamp()),
                    'score': 10,
                    'is_accepted': True
                }
            ],
            'has_more': False,
            'quota_max': 10000,
            'quota_remaining': 9999
        }
        
        mock_api_instance.fetch.return_value = mock_response
        
        client = StackOverflowClient(self.config)
        response = client.get_question_answers(12345)
        
        assert len(response.answers) == 1
        assert response.answers[0].answer_id == 100
        assert response.answers[0].question_id == 12345
        assert response.answers[0].is_accepted is True
        
        mock_api_instance.fetch.assert_called_once()

    @patch('tendance.api.so_client.StackAPI')
    def test_search_questions(self, mock_stackapi):
        """Test question search functionality"""
        mock_api_instance = Mock()
        mock_stackapi.return_value = mock_api_instance
        
        mock_response = {
            'items': [
                {
                    'question_id': 999,
                    'title': 'Apache Flink State Management',
                    'link': 'https://stackoverflow.com/questions/999',
                    'tags': ['apache-flink', 'state'],
                    'creation_date': int(datetime.now().timestamp()),
                    'last_activity_date': int(datetime.now().timestamp()),
                    'score': 15,
                    'view_count': 500,
                    'answer_count': 4,
                    'is_answered': True
                }
            ],
            'has_more': False,
            'quota_max': 10000,
            'quota_remaining': 9999
        }
        
        mock_api_instance.fetch.return_value = mock_response
        
        client = StackOverflowClient(self.config)
        response = client.search_questions(
            query="state management",
            tags=['apache-flink']
        )
        
        assert len(response.questions) == 1
        assert response.questions[0].question_id == 999
        assert "State Management" in response.questions[0].title
        
        call_args = mock_api_instance.fetch.call_args[1]
        assert call_args['q'] == "state management"
        assert call_args['tagged'] == 'apache-flink'

    @patch('tendance.api.so_client.StackAPI')
    def test_get_rate_limit_info(self, mock_stackapi):
        """Test rate limit info retrieval"""
        mock_api_instance = Mock()
        mock_stackapi.return_value = mock_api_instance
        
        client = StackOverflowClient(self.config)
        
        # Initially should be None
        assert client.get_rate_limit_info() is None
        
        # After an API call, should have rate limit info
        mock_response = {
            'items': [],
            'quota_max': 10000,
            'quota_remaining': 9999
        }
        mock_api_instance.fetch.return_value = mock_response
        
        client.get_questions()
        rate_limit = client.get_rate_limit_info()
        
        assert rate_limit is not None
        assert rate_limit.quota_max == 10000
        assert rate_limit.quota_remaining == 9999

    @patch('tendance.api.so_client.StackAPI')
    def test_save_and_load_questions(self, mock_stackapi, tmp_path):
        """Test saving and loading questions to/from file"""
        client = StackOverflowClient(self.config)
        
        # Create sample questions
        questions = [
            Question(
                question_id=1,
                title="Test Question 1",
                link="https://stackoverflow.com/questions/1",
                tags=["test"],
                creation_date=datetime.now(),
                last_activity_date=datetime.now(),
                score=5,
                view_count=100,
                answer_count=2,
                is_answered=True
            ),
            Question(
                question_id=2,
                title="Test Question 2",
                link="https://stackoverflow.com/questions/2",
                tags=["test", "apache-flink"],
                creation_date=datetime.now(),
                last_activity_date=datetime.now(),
                score=10,
                view_count=200,
                answer_count=3,
                is_answered=True
            )
        ]
        
        # Save questions
        file_path = tmp_path / "test_questions.json"
        client.save_questions_to_file(questions, file_path)
        
        # Verify file exists and has content
        assert file_path.exists()
        with open(file_path) as f:
            data = json.load(f)
        assert len(data) == 2
        
        # Load questions back
        loaded_questions = client.load_questions_from_file(file_path)
        
        assert len(loaded_questions) == 2
        assert loaded_questions[0].question_id == 1
        assert loaded_questions[1].question_id == 2
        assert loaded_questions[1].title == "Test Question 2"

    @patch('tendance.api.so_client.StackAPI')
    def test_load_questions_file_not_found(self, mock_stackapi, tmp_path):
        """Test loading questions from non-existent file"""
        client = StackOverflowClient(self.config)
        
        file_path = tmp_path / "nonexistent.json"
        questions = client.load_questions_from_file(file_path)
        
        assert questions == []

    @patch('tendance.api.so_client.StackAPI')
    def test_get_question_statistics(self, mock_stackapi):
        """Test question statistics generation"""
        client = StackOverflowClient(self.config)
        
        # Create sample questions with varying stats
        questions = [
            Question(
                question_id=1,
                title="Question 1",
                link="https://stackoverflow.com/questions/1",
                tags=["apache-flink", "java"],
                creation_date=datetime(2024, 1, 1),
                last_activity_date=datetime(2024, 1, 2),
                score=5,
                view_count=100,
                answer_count=2,
                is_answered=True,
                accepted_answer_id=10
            ),
            Question(
                question_id=2,
                title="Question 2",
                link="https://stackoverflow.com/questions/2",
                tags=["apache-flink", "scala"],
                creation_date=datetime(2024, 1, 15),
                last_activity_date=datetime(2024, 1, 16),
                score=10,
                view_count=300,
                answer_count=1,
                is_answered=True
            ),
            Question(
                question_id=3,
                title="Question 3",
                link="https://stackoverflow.com/questions/3",
                tags=["flink-sql"],
                creation_date=datetime(2024, 2, 1),
                last_activity_date=datetime(2024, 2, 2),
                score=0,
                view_count=50,
                answer_count=0,
                is_answered=False
            )
        ]
        
        stats = client.get_question_statistics(questions)
        
        assert stats['total_questions'] == 3
        assert stats['answered_questions'] == 2
        assert stats['accepted_answers'] == 1
        assert stats['answer_rate'] == 2/3
        assert stats['acceptance_rate'] == 1/3
        
        assert stats['score_statistics']['average'] == 5.0
        assert stats['score_statistics']['maximum'] == 10
        assert stats['score_statistics']['minimum'] == 0
        
        assert stats['view_statistics']['total'] == 450
        assert stats['view_statistics']['average'] == 150.0
        
        # Check top tags
        top_tags = dict(stats['top_tags'])
        assert top_tags['apache-flink'] == 2
        assert top_tags['java'] == 1
        assert top_tags['scala'] == 1
        assert top_tags['flink-sql'] == 1
        
        # Check date range
        assert stats['date_range']['span_days'] == 31  # Jan 1 to Feb 1

    @patch('tendance.api.so_client.StackAPI')
    def test_get_question_statistics_empty(self, mock_stackapi):
        """Test statistics with empty question list"""
        client = StackOverflowClient(self.config)
        
        stats = client.get_question_statistics([])
        assert stats == {}


class TestRateLimitDecorator:
    """Test the rate limit retry decorator"""
    
    def test_retry_on_rate_limit_success(self):
        """Test successful execution without retries"""
        @retry_on_rate_limit(max_retries=2)
        def mock_function():
            return "success"
        
        result = mock_function()
        assert result == "success"
    
    def test_retry_on_rate_limit_with_retries(self):
        """Test retry behavior on rate limit errors"""
        call_count = 0
        
        @retry_on_rate_limit(max_retries=3, backoff_factor=0.1)
        def mock_function():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise RateLimitError("Rate limited", backoff_seconds=1)
            return "success after retries"
        
        with patch('time.sleep') as mock_sleep:
            result = mock_function()
        
        assert result == "success after retries"
        assert call_count == 3
        assert mock_sleep.call_count == 2  # Two retries
    
    def test_retry_exhausted(self):
        """Test when all retries are exhausted"""
        @retry_on_rate_limit(max_retries=2, backoff_factor=0.1)
        def mock_function():
            raise RateLimitError("Always rate limited", backoff_seconds=1)
        
        with patch('time.sleep'):
            with pytest.raises(RateLimitError):
                mock_function()


class TestQueryFilters:
    """Test QueryFilters model"""
    
    def test_query_filters_defaults(self):
        """Test default values"""
        filters = QueryFilters()
        
        assert filters.tags is None
        assert filters.from_date is None
        assert filters.to_date is None
        assert filters.min_score is None
        assert filters.sort == QuestionSort.ACTIVITY
        assert filters.order == SortOrder.DESC
        assert filters.page == 1
        assert filters.page_size == 30
        assert filters.site == "stackoverflow"
    
    def test_query_filters_tags_parsing(self):
        """Test tag parsing from string"""
        filters = QueryFilters(tags="apache-flink,flink-sql, streaming")
        
        assert filters.tags == ["apache-flink", "flink-sql", "streaming"]
    
    def test_query_filters_validation(self):
        """Test field validation"""
        with pytest.raises(ValueError):
            QueryFilters(page=0)  # Should be >= 1
            
        with pytest.raises(ValueError):
            QueryFilters(page_size=0)  # Should be >= 1
            
        with pytest.raises(ValueError):
            QueryFilters(page_size=101)  # Should be <= 100


if __name__ == "__main__":
    pytest.main([__file__])
