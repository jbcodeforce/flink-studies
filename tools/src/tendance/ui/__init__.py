"""
Tendance Web UI module

This module provides web-based interfaces for the Tendance application,
including dataset visualization and RAG chat interfaces.
"""

from .simple_taipy_app import SimpleTendanceApp as TendanceApp

__all__ = [
    "TendanceApp",
]
