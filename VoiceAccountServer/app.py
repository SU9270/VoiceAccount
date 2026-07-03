import os
import json
import re
import uuid
from datetime import datetime, timezone

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from openai import OpenAI
from supabase import ClientOptions, create_client
from werkzeug.utils import secure_filename


load_dotenv(override=True)


app = Flask(__name__)

AUDIO_BUCKET = "user-audio"
ALLOWED_AUDIO_EXTENSIONS = {".m4a"}
DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"


def get_required_env(name):
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


supabase = create_client(
    get_required_env("SUPABASE_URL"),
    get_required_env("SUPABASE_SERVICE_ROLE_KEY"),
    options=ClientOptions(
        auto_refresh_token=False,
        persist_session=False,
    ),
)

dashscope_client = OpenAI(
    api_key=get_required_env("DASHSCOPE_API_KEY"),
    base_url=DASHSCOPE_BASE_URL,
)


@app.get("/")
def hello_flask():
    return "Hello Flask"


def extract_users(list_users_response):
    if isinstance(list_users_response, list):
        return list_users_response

    users = getattr(list_users_response, "users", None)
    if users is not None:
        return users

    data = getattr(list_users_response, "data", None)
    if isinstance(data, list):
        return data
    if data is not None and getattr(data, "users", None) is not None:
        return data.users

    return []


@app.get("/supabase-test")
def supabase_test():
    try:
        user_count = 0
        page = 1
        per_page = 1000

        while True:
            response = supabase.auth.admin.list_users(page=page, per_page=per_page)
            users = extract_users(response)
            user_count += len(users)

            if len(users) < per_page:
                break

            page += 1

        return jsonify({"connected": True, "user_count": user_count})
    except Exception as exc:
        return jsonify({"connected": False, "error": str(exc)}), 500


def normalize_categories(raw_categories):
    if not isinstance(raw_categories, list):
        return []

    categories = []
    for category in raw_categories:
        if isinstance(category, str):
            name = category.strip()
            if name:
                categories.append({"name": name})
            continue

        if not isinstance(category, dict):
            continue

        name = str(category.get("name", "")).strip()
        if not name:
            continue
        categories.append(
            {
                "name": name,
                "icon": category.get("icon"),
                "colorHex": category.get("colorHex"),
            }
        )
    return categories


def extract_json_array(text):
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
        cleaned = re.sub(r"\s*```$", "", cleaned)

    try:
        value = json.loads(cleaned)
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", cleaned)
        if not match:
            raise
        value = json.loads(match.group(0))

    if isinstance(value, dict):
        value = value.get("items") or value.get("records") or value.get("expenses")
    if not isinstance(value, list):
        raise ValueError("AI response is not a JSON array")
    return value


def normalize_ai_items(items, categories):
    category_names = [category["name"] for category in categories]
    fallback_category = category_names[0] if category_names else "其他"
    normalized = []

    for item in items:
        if not isinstance(item, dict):
            continue

        raw_amount = item.get("amount", item.get("money", item.get("price")))
        try:
            amount = float(str(raw_amount).replace(",", "").replace("¥", "").strip())
        except (TypeError, ValueError):
            continue
        if amount <= 0:
            continue

        title = str(item.get("title") or item.get("name") or item.get("description") or "").strip()
        category = str(item.get("category") or "").strip()
        if category not in category_names:
            category = fallback_category

        normalized.append(
            {
                "amount": round(amount, 2),
                "title": title or category,
                "category": category,
            }
        )

    return normalized


def collect_stream_text(completion):
    chunks = []
    usage = None
    for chunk in completion:
        if getattr(chunk, "choices", None):
            delta = chunk.choices[0].delta
            content = getattr(delta, "content", None)
            if isinstance(content, str):
                chunks.append(content)
            elif isinstance(content, list):
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        chunks.append(part.get("text", ""))
        elif getattr(chunk, "usage", None):
            usage = chunk.usage
    return "".join(chunks), usage


@app.post("/parse-audio-expenses")
def parse_audio_expenses():
    payload = request.get_json(silent=True) or {}
    audio_url = str(payload.get("audio_url") or payload.get("url") or "").strip()
    categories = normalize_categories(payload.get("categories"))

    if not audio_url:
        return jsonify({"error": "Missing required field: audio_url"}), 400
    if not categories:
        return jsonify({"error": "Missing required field: categories"}), 400

    category_names = [category["name"] for category in categories]
    prompt = (
        "你是一个中文语音记账解析助手。请听取音频内容，提取其中所有支出记录。"
        "只返回 JSON 数组，不要返回 Markdown 或解释。"
        "每个元素必须包含 amount、title、category 三个字段。"
        "amount 必须是正数，单位按人民币金额处理；title 是简短支出标题；"
        f"category 必须从以下分类中选择一个：{', '.join(category_names)}。"
        "如果音频里有多笔支出，就返回多条；如果无法识别具体标题，用最接近的消费场景命名。"
    )

    try:
        completion = dashscope_client.chat.completions.create(
            model="qwen-omni-turbo",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "input_audio", "input_audio": {"data": audio_url, "format": "m4a"}},
                        {"type": "text", "text": prompt},
                    ],
                }
            ],
            modalities=["text"],
            stream=True,
            stream_options={"include_usage": True},
        )
        raw_text, usage = collect_stream_text(completion)
        parsed_items = extract_json_array(raw_text)
        normalized_items = normalize_ai_items(parsed_items, categories)

        return jsonify(
            {
                "items": normalized_items,
                "raw": raw_text,
                "usage": usage.dict() if hasattr(usage, "dict") else None,
            }
        )
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.post("/upload-audio")
def upload_audio():
    audio_file = request.files.get("audio")
    if audio_file is None:
        return jsonify({"error": "Missing audio file. Use multipart field name 'audio'."}), 400

    original_filename = secure_filename(audio_file.filename or "")
    extension = os.path.splitext(original_filename)[1].lower() or ".m4a"
    if extension not in ALLOWED_AUDIO_EXTENSIONS:
        return jsonify({"error": "Only .m4a audio files are supported."}), 400

    audio_bytes = audio_file.read()
    if not audio_bytes:
        return jsonify({"error": "Uploaded audio file is empty."}), 400

    timestamp = datetime.now(timezone.utc)
    object_path = (
        f"recordings/{timestamp:%Y/%m/%d}/"
        f"{timestamp:%H%M%S}-{uuid.uuid4().hex}{extension}"
    )
    content_type = audio_file.mimetype or "audio/mp4"

    try:
        bucket = supabase.storage.from_(AUDIO_BUCKET)
        upload_response = bucket.upload(
            object_path,
            audio_bytes,
            {
                "content-type": content_type,
                "x-upsert": "false",
            },
        )
        public_url = bucket.get_public_url(object_path)
        signed_response = bucket.create_signed_url(object_path, 60 * 60 * 24 * 7)
        signed_url = signed_response.get("signedURL") or signed_response.get("signedUrl")

        return jsonify(
            {
                "bucket": AUDIO_BUCKET,
                "path": object_path,
                "url": signed_url or public_url,
                "public_url": public_url,
                "signed_url": signed_url,
                "upload": upload_response.dict(),
            }
        )
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
