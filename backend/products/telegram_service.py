import requests
from django.conf import settings


class TelegramService:
    """
    Service សម្រាប់ផ្ញើសារទៅ Telegram Bot
    - Super Admin → ប្រើ Chat ID ពី settings
    - Shop Owner → ប្រើ Chat ID ពី Shop Model
    """

    @staticmethod
    def send_message(text: str, chat_id: str = None) -> bool:
        """ផ្ញើសារទៅ Telegram Chat ID ជាក់លាក់"""
        if not chat_id:
            print("⚠️ Chat ID is missing")
            return False

        bot_token = getattr(settings, 'TELEGRAM_BOT_TOKEN', None)
        if not bot_token:
            print("❌ Telegram Bot Token is missing")
            return False

        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"

        payload = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        }

        try:
            response = requests.post(url, json=payload, timeout=10)
            if response.status_code == 200:
                print(f"✅ Telegram message sent to {chat_id}")
                return True
            else:
                print(f"❌ Telegram error: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"❌ Telegram exception: {e}")
            return False

    @staticmethod
    def notify_new_order(order) -> bool:
        """
        ជូនដំណឹងពេលមាន Order ថ្មី
        - បើ Order ជារបស់ Shop Owner → ផ្ញើទៅ Chat ID របស់ Shop Owner
        - បើ Order ជារបស់ Super Admin → ផ្ញើទៅ Chat ID ក្នុង settings
        """
        target_chat_id = None

        if order.shop:
            shop = order.shop
            if shop.telegram_enabled and shop.telegram_chat_id:
                target_chat_id = shop.telegram_chat_id
                print(f"🔵 Sending to Shop Owner: {shop.name}")
            else:
                print(f"⚠️ Shop {shop.name} has no Telegram Chat ID")
                target_chat_id = getattr(settings, 'TELEGRAM_CHAT_ID', None)
        else:
            target_chat_id = getattr(settings, 'TELEGRAM_CHAT_ID', None)
            print("🔵 Sending to Super Admin")

        if not target_chat_id:
            print("❌ No Telegram Chat ID available")
            return False

        # បង្កើតបញ្ជី Items
        items_list = ""
        for item in order.items.all():
            variant_text = ""
            if item.variant_options:
                variant_text = " (" + ", ".join(
                    [f"{k}: {v}" for k, v in item.variant_options.items()]
                ) + ")"
            items_list += f"  • {item.product.name}{variant_text} x{item.quantity} — ${item.price}\n"

        message = (
            f"🎉 <b>ការបង់ប្រាក់ជោគជ័យ!</b>\n\n"
            f"🏪 <b>ហាង:</b> {order.shop.name if order.shop else 'Super Admin Shop'}\n"
            f"📦 <b>Order:</b> <code>{order.order_number}</code>\n"
            f"💰 <b>តម្លៃសរុប:</b> ${order.grand_total}\n"
            f"💳 <b>វិធីបង់ប្រាក់:</b> {order.get_payment_method_display()}\n"
            f"📊 <b>Status:</b> {order.get_status_display()}\n\n"
            f"👤 <b>អតិថិជន:</b>\n"
            f"  • ឈ្មោះ: {order.full_name}\n"
            f"  • ទូរស័ព្ទ: {order.phone}\n"
            f"  • អាសយដ្ឋាន: {order.address}, {order.city}\n\n"
            f"🛒 <b>ផលិតផល:</b>\n{items_list}\n"
            f"⏰ <b>កាលបរិច្ឆេទ:</b> {order.created_at.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
            f"✅ សូមពិនិត្យ និងដំណើរការការបញ្ជាទិញនេះ។"
        )

        return TelegramService.send_message(message, chat_id=target_chat_id)