from django.conf import settings


def send_otp_sms(phone_number: str, code: str, purpose: str = "signup"):
    """
    Sends the OTP code to the user's phone.

    Right now this is a MOCK sender: it just prints the code to the console
    and returns it, so you can test the whole flow without a real SMS provider.

    To go live, replace the body of this function with a call to a real
    SMS gateway, for example Twilio:

        from twilio.rest import Client
        client = Client(settings.TWILIO_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(
            body=f"Your verification code is {code}",
            from_=settings.TWILIO_PHONE_NUMBER,
            to=phone_number,
        )

    Cambodia-friendly alternatives: Twilio, Vonage, or a local SMS gateway
    (e.g. an SMS aggregator that supports Smart/Cellcard/Metfone numbers).
    """
    message = f"[OTP] Your {purpose} verification code for phone {phone_number} is: {code}"
    print(message)  # In production, remove this and call the real SMS API instead.
    return True
