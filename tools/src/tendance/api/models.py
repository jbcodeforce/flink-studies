#!/usr/bin/env python3
"""
Pydantic models for Stack Exchange API responses
"""

from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, field_validator, ConfigDict
from enum import Enum


class SortOrder(str, Enum):
    """Sort order enumeration"""
    ASC = "asc"
    DESC = "desc"


class QuestionSort(str, Enum):
    """Question sort options"""
    ACTIVITY = "activity"
    VOTES = "votes" 
    CREATION = "creation"
    HOT = "hot"
    WEEK = "week"
    MONTH = "month"


class QuestionState(str, Enum):
    """Question state enumeration"""
    OPEN = "open"
    CLOSED = "closed"
    DELETED = "deleted"


class User(BaseModel):
    """Stack Exchange user model"""
    user_id: int = Field(alias="user_id")
    display_name: str = Field(alias="display_name")
    reputation: int = Field(default=0)
    user_type: Optional[str] = Field(alias="user_type", default=None)
    profile_image: Optional[str] = Field(alias="profile_image", default=None)
    link: Optional[str] = Field(default=None)


class Question(BaseModel):
    """Stack Exchange question model"""
    question_id: int = Field(alias="question_id")
    title: str
    link: str
    tags: List[str] = Field(default_factory=list)
    owner: Optional[User] = None
    creation_date: datetime = Field(alias="creation_date")
    last_activity_date: datetime = Field(alias="last_activity_date")
    last_edit_date: Optional[datetime] = Field(alias="last_edit_date", default=None)
    score: int = Field(default=0)
    view_count: int = Field(alias="view_count", default=0)
    answer_count: int = Field(alias="answer_count", default=0)
    accepted_answer_id: Optional[int] = Field(alias="accepted_answer_id", default=None)
    is_answered: bool = Field(alias="is_answered", default=False)
    body: Optional[str] = Field(default=None)
    body_markdown: Optional[str] = Field(alias="body_markdown", default=None)
    closed_date: Optional[datetime] = Field(alias="closed_date", default=None)
    closed_reason: Optional[str] = Field(alias="closed_reason", default=None)
    
    @field_validator('creation_date', 'last_activity_date', 'last_edit_date', 'closed_date', mode='before')
    @classmethod
    def parse_timestamp(cls, v):
        """Convert Unix timestamp to datetime"""
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return datetime.fromtimestamp(v)
        return v


class Answer(BaseModel):
    """Stack Exchange answer model"""
    answer_id: int = Field(alias="answer_id")
    question_id: int = Field(alias="question_id")
    owner: Optional[User] = None
    creation_date: datetime = Field(alias="creation_date")
    last_activity_date: datetime = Field(alias="last_activity_date")
    last_edit_date: Optional[datetime] = Field(alias="last_edit_date", default=None)
    score: int = Field(default=0)
    is_accepted: bool = Field(alias="is_accepted", default=False)
    body: Optional[str] = Field(default=None)
    body_markdown: Optional[str] = Field(alias="body_markdown", default=None)
    
    @field_validator('creation_date', 'last_activity_date', 'last_edit_date', mode='before')
    @classmethod
    def parse_timestamp(cls, v):
        """Convert Unix timestamp to datetime"""
        if v is None:
            return None
        if isinstance(v, (int, float)):
            return datetime.fromtimestamp(v)
        return v


class QueryFilters(BaseModel):
    """Query filters for Stack Exchange API"""
    tags: Optional[List[str]] = Field(default=None, description="Tags to filter by")
    from_date: Optional[datetime] = Field(default=None, description="Start date filter")
    to_date: Optional[datetime] = Field(default=None, description="End date filter")
    min_score: Optional[int] = Field(default=None, description="Minimum score filter")
    sort: QuestionSort = Field(default=QuestionSort.ACTIVITY, description="Sort field")
    order: SortOrder = Field(default=SortOrder.DESC, description="Sort order")
    page: int = Field(default=1, ge=1, description="Page number")
    page_size: int = Field(default=30, ge=1, le=100, description="Items per page")
    site: str = Field(default="stackoverflow", description="Stack Exchange site")
    
    @field_validator('tags', mode='before')
    @classmethod
    def parse_tags(cls, v):
        """Parse tags from string or list"""
        if v is None:
            return None
        if isinstance(v, str):
            return [tag.strip() for tag in v.split(',') if tag.strip()]
        return v


class ApiResponse(BaseModel):
    """Generic API response wrapper"""
    items: List[Dict[str, Any]] = Field(default_factory=list)
    has_more: bool = Field(default=False)
    quota_max: int = Field(default=0)
    quota_remaining: int = Field(default=0)
    page: int = Field(default=1)
    page_size: int = Field(default=30)
    total: Optional[int] = Field(default=None)
    error_id: Optional[int] = Field(default=None)
    error_message: Optional[str] = Field(default=None)
    error_name: Optional[str] = Field(default=None)


class QuestionsResponse(BaseModel):
    """Questions API response"""
    questions: List[Question] = Field(default_factory=list)
    has_more: bool = Field(default=False)
    quota_max: int = Field(default=0)
    quota_remaining: int = Field(default=0)
    page: int = Field(default=1)
    page_size: int = Field(default=30)
    total_questions: Optional[int] = Field(default=None)


class AnswersResponse(BaseModel):
    """Answers API response"""
    answers: List[Answer] = Field(default_factory=list)
    has_more: bool = Field(default=False)
    quota_max: int = Field(default=0)
    quota_remaining: int = Field(default=0)
    page: int = Field(default=1)
    page_size: int = Field(default=30)


class RateLimitInfo(BaseModel):
    """Rate limit information"""
    quota_max: int
    quota_remaining: int
    backoff_seconds: Optional[int] = Field(default=None)
    
    @property
    def quota_used(self) -> int:
        """Calculate used quota"""
        return self.quota_max - self.quota_remaining
    
    @property
    def quota_percentage_used(self) -> float:
        """Calculate percentage of quota used"""
        if self.quota_max == 0:
            return 0.0
        return (self.quota_used / self.quota_max) * 100


class ClientConfig(BaseModel):
    """Stack Overflow client configuration"""
    api_key: Optional[str] = Field(default=None, description="Stack Exchange API key")
    site: str = Field(default="stackoverflow", description="Stack Exchange site")
    default_page_size: int = Field(default=30, ge=1, le=100, description="Default page size")
    max_retries: int = Field(default=3, ge=0, description="Maximum retry attempts")
    timeout_seconds: int = Field(default=30, ge=1, description="Request timeout")
    respect_backoff: bool = Field(default=True, description="Respect API backoff headers")
    user_agent: str = Field(default="Tendance/1.0", description="User agent string")
    
    model_config = ConfigDict(env_prefix="STACKEXCHANGE_")
