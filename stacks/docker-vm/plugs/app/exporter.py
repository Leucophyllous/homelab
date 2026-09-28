import asyncio
import os
import aiohttp
from aiohttp import web

MATTER_WS = os.environ.get("MATTER_WS", "ws://127.0.0.1:5580/ws")
TOKEN = os.environ["PLUG_TOKEN"]
MATTER_NODE = int(os.environ.get("MATTER_NODE", "1"))
SWITCH_ENTITY = "switch.smart_wi_fi_plug"


async def matter_call(payload):
    async with aiohttp.ClientSession() as s:
        async with s.ws_connect(MATTER_WS, timeout=5) as ws:
            await ws.receive_json(timeout=5)
            await ws.send_json(payload)
            return await ws.receive_json(timeout=10)


async def matter_read():
    r = await matter_call({"message_id": "1", "command": "get_nodes"})
    for n in r["result"]:
        if n["node_id"] == MATTER_NODE:
            return n
    raise RuntimeError("node not found")


def line(name, labels, value):
    lb = ",".join("%s=\"%s\"" % (k, v) for k, v in labels.items())
    return "%s{%s} %s" % (name, lb, value)


async def metrics(request):
    out = []
    up = 0
    try:
        n = await matter_read()
        a = n["attributes"]
        up = 1 if n["available"] else 0
        out.append(line("hass_sensor_power_w", {"domain": "sensor", "entity": "sensor.smart_wi_fi_plug_hawa", "friendly_name": "UPS_Plug 電力"}, a["1/144/8"] / 1000))
        out.append(line("hass_sensor_voltage_v", {"domain": "sensor", "entity": "sensor.ups_plug_you_xiao_dian_ya", "friendly_name": "UPS_Plug 有効電圧"}, a["1/144/11"] / 1000))
        out.append(line("hass_sensor_current_a", {"domain": "sensor", "entity": "sensor.ups_plug_you_xiao_dian_liu", "friendly_name": "UPS_Plug 有効電流"}, a["1/144/12"] / 1000))
        out.append(line("hass_sensor_energy_kwh", {"domain": "sensor", "entity": "sensor.smart_wi_fi_plug_eneruki", "friendly_name": "UPS_Plug エネルギー"}, a["1/145/1"]["0"] / 1000000))
        out.append(line("hass_switch_state", {"domain": "switch", "entity": SWITCH_ENTITY, "friendly_name": "UPS_Plug"}, 1 if a["1/6/0"] else 0))
    except Exception:
        up = 0
    out.append(line("plug_up", {"plug": "ups"}, up))
    return web.Response(text="\n".join(out) + "\n", content_type="text/plain")


async def switch(request):
    if request.headers.get("X-Token") != TOKEN:
        return web.json_response({"ok": False, "error": "forbidden"}, status=403)
    act = request.match_info["act"]
    if act not in ("on", "off", "state"):
        return web.json_response({"ok": False, "error": "bad request"}, status=400)
    try:
        if act != "state":
            await matter_call({"message_id": "2", "command": "device_command", "args": {"node_id": MATTER_NODE, "endpoint_id": 1, "cluster_id": 6, "command_name": "On" if act == "on" else "Off", "payload": {}}})
            await asyncio.sleep(1)
        n = await matter_read()
        return web.json_response({"ok": True, "on": bool(n["attributes"]["1/6/0"])})
    except Exception as e:
        return web.json_response({"ok": False, "error": type(e).__name__}, status=502)


app = web.Application()
app.router.add_get("/metrics", metrics)
app.router.add_post("/switch/{act}", switch)
web.run_app(app, host="0.0.0.0", port=int(os.environ.get("PORT", "9877")), print=None)
