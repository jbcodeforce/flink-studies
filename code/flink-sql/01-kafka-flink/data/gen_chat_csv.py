#!/usr/bin/env python3
"""Generate synthetic chat conversation CSV: user_id, session_id, role, user_msg."""
import csv
import random
from pathlib import Path

# Human prompts (short, up to 150 chars)
HUMAN_PROMPTS = [
    "What's the weather like?",
    "How do I reset my password?",
    "Can you explain machine learning in simple terms?",
    "Best way to learn Python?",
    "Tell me a joke.",
    "What are the top 3 restaurants nearby?",
    "How does Kafka work?",
    "Help me debug this SQL query.",
    "What's the difference between batch and streaming?",
    "How do I deploy Flink on Kubernetes?",
    "Recommend a good book on data engineering.",
    "Why is my job failing?",
    "Explain windowing in stream processing.",
    "How do I connect Flink to Kafka?",
    "What's checkpointing?",
    "Is this the right approach?",
    "Can you summarize the docs?",
    "How do I scale my pipeline?",
    "What's event time vs processing time?",
    "Help with schema evolution.",
    "How do I backfill data?",
    "What's the latency I should expect?",
    "Explain exactly what you did.",
    "Any tips for testing?",
    "How do I monitor my Flink job?",
]

# AI response fragments (combined to build up to 400 chars)
AI_FRAGMENTS = [
    "Sure. Here's a concise explanation. ",
    "The key points are: first, ensure your configuration is correct; second, check the logs for errors; third, validate your schema. ",
    "In practice, you'll want to consider latency requirements and throughput. ",
    "I recommend starting with the official documentation and then trying a small proof of concept. ",
    "Common causes include misconfigured connectors, schema mismatches, or network timeouts. ",
    "You can verify this by running a simple test and checking the metrics in the dashboard. ",
    "Best practice is to use idempotent sinks and enable checkpointing for exactly-once semantics. ",
    "The main difference is that streaming processes data as it arrives, while batch processes bounded datasets. ",
    "For production, consider high availability, monitoring, and alerting. ",
    "Remember to set appropriate timeouts and retry policies. ",
]

def human_msg():
    p = random.choice(HUMAN_PROMPTS)
    if random.random() < 0.3:
        p += " " + random.choice(["Thanks.", "Please be brief.", "More detail?", "Quick answer only."])
    return p[:150]

def ai_msg():
    n = random.randint(2, 6)
    parts = random.choices(AI_FRAGMENTS, k=n)
    s = "".join(parts).strip()
    return s[:400]

def main():
    out_path = Path(__file__).resolve().parent / "chat_conversations.csv"
    target_rows = 100
    rows_per_session = 10  # 5 interactions = 5 human + 5 AI
    num_sessions = target_rows // rows_per_session  # 10 sessions

    user_ids = [f"user_{i:03d}" for i in range(1, num_sessions + 1)]
    sessions = [f"session_{i:03d}" for i in range(1, num_sessions + 1)]

    rows = []
    for si, session_id in enumerate(sessions):
        uid = user_ids[si]
        for i in range(rows_per_session):
            role = "human" if i % 2 == 0 else "ai"
            msg = human_msg() if role == "human" else ai_msg()
            rows.append((uid, session_id, role, msg))

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        w.writerow(["user_id", "session_id", "role", "user_msg"])
        w.writerows(rows)

    print(f"Wrote {len(rows)} records to {out_path}")

if __name__ == "__main__":
    main()
