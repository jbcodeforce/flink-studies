"""
API module for Tendance Stack Exchange Content Analyzer
"""

from .so_client import StackOverflowClient, StackExchangeError, RateLimitError, QuotaExhaustedError
from .models import (
    Question,
    Answer,
    QueryFilters,
    QuestionsResponse,
    AnswersResponse,
    ClientConfig,
    RateLimitInfo,
    QuestionSort,
    SortOrder,
)

__all__ = [
    "StackOverflowClient",
    "StackExchangeError", 
    "RateLimitError",
    "QuotaExhaustedError",
    "Question",
    "Answer",
    "QueryFilters",
    "QuestionsResponse",
    "AnswersResponse",
    "ClientConfig",
    "RateLimitInfo",
    "QuestionSort",
    "SortOrder",
]
