#!/usr/bin/env python3
"""
Unit tests for Tendance CLI functionality
"""

import pytest
from pathlib import Path
from typer.testing import CliRunner
from unittest.mock import patch, MagicMock

from tendance.cli import app, __version__


class TestCLI:
    """Test class for CLI functionality"""
    
    def setup_method(self):
        """Set up test runner for each test"""
        self.runner = CliRunner()

    def test_version_command(self):
        """Test the version command displays correct version"""
        result = self.runner.invoke(app, ["version"])
        
        assert result.exit_code == 0
        assert __version__ in result.stdout
        assert "Tendance CLI version" in result.stdout
        assert "Stack Exchange Content Analyzer" in result.stdout

    def test_help_command(self):
        """Test the help command shows all available commands"""
        result = self.runner.invoke(app, ["--help"])
        
        assert result.exit_code == 0
        assert "Stack Exchange Content Analyzer" in result.stdout
        assert "version" in result.stdout
        assert "analyze" in result.stdout
        assert "ui" in result.stdout

    def test_analyze_command_no_params(self):
        """Test analyze command without required parameters shows error"""
        result = self.runner.invoke(app, ["analyze"])
        
        assert result.exit_code == 1
        assert "Error: Either --subject or --config must be provided" in result.stdout
        assert "Try: tendance analyze --subject apache-flink" in result.stdout

    def test_analyze_command_with_subject(self):
        """Test analyze command with subject parameter"""
        result = self.runner.invoke(app, [
            "analyze", 
            "--subject", "apache-flink",
            "--from-date", "2024-01-01"
        ])
        
        assert result.exit_code == 0
        assert "Tendance Stack Exchange Analyzer" in result.stdout
        assert "Subject: apache-flink" in result.stdout
        assert "Date range: 2024-01-01 to current" in result.stdout
        assert "Output: output (json)" in result.stdout

    def test_analyze_command_with_config(self, tmp_path):
        """Test analyze command with config file parameter"""
        config_file = tmp_path / "test_config.yaml"
        config_file.write_text("test: config")
        
        result = self.runner.invoke(app, [
            "analyze",
            "--config", str(config_file)
        ])
        
        assert result.exit_code == 0
        assert "Tendance Stack Exchange Analyzer" in result.stdout
        assert "Subject: From config file" in result.stdout

    def test_analyze_command_all_params(self):
        """Test analyze command with all parameters"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "apache-flink",
            "--tags", "flink-sql,streaming",
            "--from-date", "2024-01-01",
            "--to-date", "2025-08-31",
            "--output-dir", "/tmp/output",
            "--formats", "json,csv",
            "--min-score", "5"
        ])
        
        assert result.exit_code == 0
        assert "apache-flink" in result.stdout
        assert "2024-01-01 to 2025-08-31" in result.stdout
        assert "/tmp/output (json, csv)" in result.stdout

    def test_ui_command_basic(self):
        """Test UI command basic functionality"""
        result = self.runner.invoke(app, ["ui"])
        
        assert result.exit_code == 0
        assert "Launching Tendance Web Dashboard" in result.stdout
        assert "Dashboard will be available at: http://localhost:8501" in result.stdout
        assert "Web UI not implemented yet" in result.stdout

    def test_ui_command_with_subject(self):
        """Test UI command with subject parameter"""
        result = self.runner.invoke(app, [
            "ui",
            "--subject", "apache-flink"
        ])
        
        assert result.exit_code == 0
        assert "Subject: apache-flink" in result.stdout
        assert "http://localhost:8501" in result.stdout

    def test_ui_command_with_custom_port(self):
        """Test UI command with custom port"""
        result = self.runner.invoke(app, [
            "ui",
            "--port", "9000"
        ])
        
        assert result.exit_code == 0
        assert "http://localhost:9000" in result.stdout

    def test_ui_command_with_config(self, tmp_path):
        """Test UI command with config file"""
        config_file = tmp_path / "ui_config.yaml"
        config_file.write_text("subject: test-subject")
        
        result = self.runner.invoke(app, [
            "ui",
            "--config", str(config_file)
        ])
        
        assert result.exit_code == 0
        assert "Config:" in result.stdout
        # Check for filename rather than full path due to Rich console wrapping
        assert "ui_config.yaml" in result.stdout

    def test_analyze_help(self):
        """Test analyze command help"""
        result = self.runner.invoke(app, ["analyze", "--help"])
        
        assert result.exit_code == 0
        assert "Analyze Stack Exchange content" in result.stdout
        assert "--subject" in result.stdout
        assert "--tags" in result.stdout
        assert "--from-date" in result.stdout

    def test_ui_help(self):
        """Test UI command help"""
        result = self.runner.invoke(app, ["ui", "--help"])
        
        assert result.exit_code == 0
        assert "Launch the interactive web dashboard" in result.stdout
        assert "--subject" in result.stdout
        assert "--port" in result.stdout

    def test_invalid_command(self):
        """Test invalid command shows error"""
        result = self.runner.invoke(app, ["invalid-command"])
        
        assert result.exit_code != 0
        # Typer shows error differently - just check that it failed

    def test_analyze_with_resume(self, tmp_path):
        """Test analyze command with resume parameter"""
        resume_file = tmp_path / "resume.json"
        resume_file.write_text('{"state": "test"}')
        
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "apache-flink",
            "--resume", str(resume_file)
        ])
        
        assert result.exit_code == 0
        assert "apache-flink" in result.stdout

    @pytest.mark.parametrize("format_type", ["json", "csv", "markdown", "json,csv", "json,csv,markdown"])
    def test_analyze_different_formats(self, format_type):
        """Test analyze command with different output formats"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "test-subject",
            "--formats", format_type
        ])
        
        assert result.exit_code == 0
        # Format types have spaces after commas in the output
        expected_format = format_type.replace(',', ', ')
        assert f"output ({expected_format})" in result.stdout

    @pytest.mark.parametrize("score", [0, 1, 5, 10])
    def test_analyze_min_score(self, score):
        """Test analyze command with different minimum scores"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "test-subject",
            "--min-score", str(score)
        ])
        
        assert result.exit_code == 0
        assert "test-subject" in result.stdout

    def test_analyze_output_directory_creation(self, tmp_path):
        """Test analyze command with custom output directory"""
        output_dir = tmp_path / "custom_output"
        
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "test-subject",
            "--output-dir", str(output_dir)
        ])
        
        assert result.exit_code == 0
        # Check that the output directory name appears in the output (may be wrapped)
        assert "custom_output" in result.stdout

    def test_version_with_verbose_flag(self):
        """Test version command output format"""
        result = self.runner.invoke(app, ["version"])
        
        # Check that the output contains the expected format elements
        assert result.exit_code == 0
        output_lines = result.stdout.strip().split('\n')
        
        # Should have multiple lines due to Rich panel formatting
        assert len(output_lines) > 1
        
        # Check for key content
        full_output = result.stdout
        assert "Tendance CLI version: 0.1.0" in full_output
        assert "Stack Exchange Content Analyzer" in full_output

    def test_analyze_date_validation_format(self):
        """Test that analyze accepts properly formatted dates"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "test",
            "--from-date", "2024-01-01",
            "--to-date", "2024-12-31"
        ])
        
        assert result.exit_code == 0
        assert "2024-01-01 to 2024-12-31" in result.stdout

    def test_ui_all_parameters(self, tmp_path):
        """Test UI command with all parameters"""
        config_file = tmp_path / "full_config.yaml"
        config_file.write_text("test: full-config")
        
        result = self.runner.invoke(app, [
            "ui",
            "--subject", "apache-flink",
            "--config", str(config_file),
            "--port", "3000"
        ])
        
        assert result.exit_code == 0
        assert "apache-flink" in result.stdout
        assert "Config:" in result.stdout
        assert "full_config.yaml" in result.stdout
        assert "http://localhost:3000" in result.stdout


class TestCLIEdgeCases:
    """Test edge cases and error conditions"""
    
    def setup_method(self):
        """Set up test runner for each test"""
        self.runner = CliRunner()

    def test_analyze_both_subject_and_config(self, tmp_path):
        """Test analyze command with both subject and config (should work)"""
        config_file = tmp_path / "config.yaml"
        config_file.write_text("test: config")
        
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "apache-flink",
            "--config", str(config_file)
        ])
        
        # Should work - CLI accepts both parameters
        assert result.exit_code == 0
        assert "apache-flink" in result.stdout

    def test_nonexistent_config_file(self):
        """Test analyze command with non-existent config file"""
        result = self.runner.invoke(app, [
            "analyze",
            "--config", "/nonexistent/config.yaml"
        ])
        
        # Should still run (file validation not implemented yet)
        assert result.exit_code == 0

    def test_empty_subject(self):
        """Test analyze command with empty subject string"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", ""
        ])
        
        # Empty subject should be treated as missing and show error
        assert result.exit_code == 1
        assert "Error: Either --subject or --config must be provided" in result.stdout

    def test_negative_min_score(self):
        """Test analyze command with negative min score"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "test",
            "--min-score", "-5"
        ])
        
        # Negative scores should be accepted
        assert result.exit_code == 0

    def test_zero_port(self):
        """Test UI command with port 0"""
        result = self.runner.invoke(app, [
            "ui",
            "--port", "0"
        ])
        
        assert result.exit_code == 0
        assert "http://localhost:0" in result.stdout

    def test_high_port_number(self):
        """Test UI command with high port number"""
        result = self.runner.invoke(app, [
            "ui",
            "--port", "65535"
        ])
        
        assert result.exit_code == 0
        assert "http://localhost:65535" in result.stdout


class TestCLIFixtures:
    """Test CLI with pytest fixtures"""
    
    def setup_method(self):
        """Set up test runner for each test"""
        self.runner = CliRunner()

    def test_analyze_with_temp_config(self, temp_config_file):
        """Test analyze command with temporary config file fixture"""
        result = self.runner.invoke(app, [
            "analyze",
            "--config", str(temp_config_file)
        ])
        
        assert result.exit_code == 0
        assert "From config file" in result.stdout
        
    def test_analyze_with_temp_output_dir(self, temp_output_dir):
        """Test analyze command with temporary output directory fixture"""
        result = self.runner.invoke(app, [
            "analyze",
            "--subject", "test-fixture",
            "--output-dir", str(temp_output_dir)
        ])
        
        assert result.exit_code == 0
        assert "test-fixture" in result.stdout


if __name__ == "__main__":
    pytest.main([__file__])
