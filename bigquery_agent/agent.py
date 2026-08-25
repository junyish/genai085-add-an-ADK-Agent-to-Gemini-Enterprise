# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import datetime
from zoneinfo import ZoneInfo
from dotenv import load_dotenv

from google.adk.agents import Agent
from google.adk.tools.bigquery import BigQueryToolset, BigQueryCredentialsConfig
from google.adk.tools.bigquery.config import BigQueryToolConfig, WriteMode
from google.adk.models import Gemini
from google.genai import types

import google.auth

import google.cloud.logging

load_dotenv()
cloud_logging_client = google.cloud.logging.Client(project=os.getenv('GOOGLE_CLOUD_PROJECT'))
cloud_logging_client.setup_logging()

from .callback_logging import log_query_to_model, log_model_response

RETRY_OPTIONS = types.HttpRetryOptions(initial_delay=1, max_delay=3, attempts=30)

# Uses externally-managed Application Default Credentials (ADC) by default.
# This decouples authentication from the agent / tool lifecycle.
# https://cloud.google.com/docs/authentication/provide-credentials-adc
application_default_credentials, _ = google.auth.default()
credentials_config = BigQueryCredentialsConfig(
    credentials=application_default_credentials)

# Define a tool configuration to block any write operations
tool_config = BigQueryToolConfig(write_mode=WriteMode.ALLOWED)

# Instantiate a BigQuery toolset
bigquery_toolset = BigQueryToolset(
    credentials_config=credentials_config,
    bigquery_tool_config=tool_config
)


def get_current_time():
    """
    Retrieves the current time.

    Returns:
        A dict with the current time.
    """
    now = datetime.datetime.now(ZoneInfo("America/New_York"))
    return {"current_time": now.strftime("%Y-%m-%d %H:%M:%S")}


# Agent Definition
root_agent = Agent(
    model=Gemini(model=os.getenv("MODEL"), retry_options=RETRY_OPTIONS),
    name="bigquery_agent",
    description=(
        "Agent to answer questions about BigQuery data and models and execute"
        " SQL queries."
    ),
    instruction=f"""
        You are a data science agent with access to several BigQuery tools.
        Make use of those tools to answer the user's questions.

        When using the bigquery_toolset tool, always use the 
        project {os.getenv('GOOGLE_CLOUD_PROJECT')}
        and the dataset named `pool_data`.
    """,
    before_model_callback=log_query_to_model,
    after_model_callback=log_model_response,
    tools=[bigquery_toolset, get_current_time],
)
