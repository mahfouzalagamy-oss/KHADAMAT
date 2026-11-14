"""Exercise phone OTP and request ownership through the local Supabase API."""

import json
import os
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from uuid import uuid4


ORIGIN = "http://127.0.0.1:54321"


def call(path, *, token=None, payload=None, expected=200):
    headers = {"apikey": os.environ["KHADAMAT_LOCAL_ANON_KEY"]}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    body = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(payload).encode()
    request = Request(ORIGIN + path, data=body, headers=headers)
    try:
        with urlopen(request, timeout=15) as response:
            status, data = response.status, response.read()
    except HTTPError as error:
        status, data = error.code, error.read()
    if status != expected:
        code = json.loads(data).get("code") if data.startswith(b"{") else None
        raise AssertionError(f"{path}: expected {expected}, got {status} ({code})")
    return json.loads(data) if data else None


def sign_in(phone, code):
    call("/auth/v1/otp", payload={"phone": phone})
    call("/auth/v1/verify", payload={"phone": phone, "token": "999999", "type": "sms"}, expected=403)
    result = call("/auth/v1/verify", payload={"phone": phone, "token": code, "type": "sms"})
    return result["access_token"]


def main():
    first = sign_in("+201012345678", "431278")
    second = sign_in("+201112345678", "642819")
    request_list = "/rest/v1/khadamat_service_requests?select=id,status"
    submit = "/rest/v1/rpc/khadamat_submit_request"
    details = {
        "p_submission_id": str(uuid4()),
        "p_service_code": "ac",
        "p_district": "حي الجامعة",
        "p_address": "عنوان اختبار محلي",
        "p_description": "التكييف لا يبرد",
    }

    assert call("/rest/v1/rpc/khadamat_my_roles", token=first, payload={}) == ["customer"]
    request_id = call(submit, token=first, payload=details)
    assert call(submit, token=first, payload=details) == request_id
    assert call(request_list, token=first) == [{"id": request_id, "status": "submitted"}]
    assert call(request_list, token=second) == []
    call(submit, payload=details, expected=401)
    print("Phone OTP, request submission, idempotent retry and account isolation passed.")


if __name__ == "__main__":
    main()
