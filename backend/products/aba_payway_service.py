import base64
import hashlib
import hmac
import json
import requests
from django.conf import settings
from datetime import datetime


class AbaPaywayService:
    """
    Service សម្រាប់ភ្ជាប់ជាមួយ ABA PayWay API
    Documentation: https://developer.payway.com.kh/
    """

    @staticmethod
    def generate_qr(
        amount: float,
        tran_id: str,
        first_name: str,
        last_name: str,
        email: str,
        phone: str,
        payment_option: str = "abapay_khqr",
        currency: str = "USD",
        callback_url: str = "",
        lifetime: int = 6,
    ) -> dict:
        """
        បង្កើត KHQR Code តាមរយៈ ABA PayWay API
        Endpoint: /api/payment-gateway/v1/payments/purchase
        """
        merchant_id = settings.ABA_PAYWAY_MERCHANT_ID
        api_key = settings.ABA_PAYWAY_API_KEY
        base_url = settings.ABA_PAYWAY_BASE_URL

        # ✅ req_time
        req_time = datetime.now().strftime("%Y%m%d%H%M%S")

        # ✅ Items ត្រូវជា Base64 Encoded JSON (ទំនេរ = [])
        items_json = json.dumps([])
        items_base64 = base64.b64encode(items_json.encode('utf-8')).decode('utf-8')

        # ✅ Field ទំនេរផ្សេងទៀត
        return_deeplink = ""
        custom_fields = ""
        return_params = ""
        payout = ""
        qr_image_template = "template3_color"

        # ✅ callback_url ត្រូវ Base64 -- ត្រូវប្រើតម្លៃ Base64 ដូចគ្នា
        # ទាំងក្នុង Hash និងក្នុង Payload (មិនមែនប្រើ URL ដើមក្នុង Hash ទេ)
        callback_url_base64 = (
            base64.b64encode(callback_url.encode('utf-8')).decode('utf-8')
            if callback_url else ""
        )

        # ============================================================
        # ✅ Hash Data Order ត្រឹមត្រូវតាម ABA QR API Documentation
        # (https://developer.payway.com.kh/qr-api-14530840e0.md)
        # លំដាប់៖ req_time + merchant_id + tran_id + amount + items
        #        + first_name + last_name + email + phone + purchase_type
        #        + payment_option + callback_url + return_deeplink
        #        + currency + custom_fields + return_params + payout
        #        + lifetime + qr_image_template
        # ⚠️ សម្គាល់៖ គ្មាន "shipping" ក្នុង Hash នេះទេ (ត្រូវយកចេញ)
        # ⚠️ callback_url ត្រូវប្រើ Base64 (មិនមែន URL ដើម)
        # ============================================================
        hash_data = (
            req_time
            + merchant_id
            + tran_id
            + f"{amount:.2f}"
            + items_base64
            + first_name
            + last_name
            + email
            + phone
            + "purchase"
            + payment_option
            + callback_url_base64   # ✅ ប្តូរមកប្រើ Base64 ដូចក្នុង Payload
            + return_deeplink
            + currency
            + custom_fields
            + return_params
            + payout
            + str(lifetime)
            + qr_image_template
        )

        hash_value = base64.b64encode(
            hmac.new(
                api_key.encode("utf-8"),
                hash_data.encode("utf-8"),
                hashlib.sha512,
            ).digest()
        ).decode("utf-8")

        payload = {
            "req_time": req_time,
            "merchant_id": merchant_id,
            "tran_id": tran_id,
            "first_name": first_name,
            "last_name": last_name,
            "email": email,
            "phone": phone,
            "amount": f"{amount:.2f}",
            "purchase_type": "purchase",
            "payment_option": payment_option,
            "items": items_base64,
            "currency": currency,
            "callback_url": callback_url_base64,
            "return_deeplink": return_deeplink,
            "custom_fields": custom_fields,
            "return_params": return_params,
            "payout": payout,
            "lifetime": lifetime,
            "qr_image_template": qr_image_template,
            "hash": hash_value,
        }

        # ✅ ត្រូវប្រើ /generate-qr មិនមែន /purchase ទេ ព្រោះ Hash Formula
        # ដែលបានគណនាខាងលើ ត្រូវគ្នាទៅនឹង endpoint នេះប៉ុណ្ណោះ
        # (/purchase ត្រូវការ Hash Formula ខុសគ្នា — មាន shipping, return_url ជាដើម)
        url = f"{base_url}/api/payment-gateway/v1/payments/generate-qr"

        print(f"🔵 ABA PayWay URL: {url}")
        print(f"🔵 Hash Data: {hash_data}")
        print(f"🔵 Payload: {json.dumps(payload, indent=2)}")

        response = requests.post(url, json=payload, timeout=30)

        print(f"🔵 Status Code: {response.status_code}")
        print(f"🔵 Response: {response.text[:500]}")

        try:
            return response.json()
        except Exception as e:
            return {
                "status": {"code": "99", "message": f"Invalid response: {response.text[:200]}"},
                "raw_response": response.text[:500],
            }

    @staticmethod
    def check_transaction(tran_id: str) -> dict:
        """
        ពិនិត្យថាតើ Transaction បានបង់ប្រាក់ហើយឬនៅ
        """
        merchant_id = settings.ABA_PAYWAY_MERCHANT_ID
        api_key = settings.ABA_PAYWAY_API_KEY
        base_url = settings.ABA_PAYWAY_BASE_URL

        req_time = datetime.now().strftime("%Y%m%d%H%M%S")

        # ✅ Hash Data សម្រាប់ Check Transaction
        hash_data = req_time + merchant_id + tran_id

        hash_value = base64.b64encode(
            hmac.new(
                api_key.encode("utf-8"),
                hash_data.encode("utf-8"),
                hashlib.sha512,
            ).digest()
        ).decode("utf-8")

        payload = {
            "req_time": req_time,
            "merchant_id": merchant_id,
            "tran_id": tran_id,
            "hash": hash_value,
        }

        url = f"{base_url}/api/payment-gateway/v1/payments/check-transaction-2"
        response = requests.post(url, json=payload, timeout=30)

        try:
            return response.json()
        except Exception:
            return {
                "status": {"code": "99", "message": "Invalid response"},
                "raw_response": response.text[:500],
            }