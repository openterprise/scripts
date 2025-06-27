from fastapi import FastAPI, Depends, HTTPException
from fastapi.responses import StreamingResponse
from pyhon import Hon
from pyhon.exceptions import HonAuthenticationError
from datetime import datetime, timezone
import pytz  # You may need to install this: pip install pytz
import time
from datetime import datetime
import asyncio

#run as: uvicorn ac:app --host 0.0.0.0 --port 8000

EMAIL = ""
PASSWORD = ""

app = FastAPI()
hon_instance: Hon | None = None


async def init_hon():
    print(f"{datetime.now().isoformat()} init_hon() called")
    global hon_instance
    hon = Hon(EMAIL, PASSWORD)
    await hon.__aenter__()  # Log in and load appliances automatically
    hon_instance = hon
    print("✅ HON initialized with", len(hon.appliances), "devices")
    return hon


@app.on_event("startup")
async def startup_event():
    #await init_hon()
    # just pass, hon will be inited during first HTTP client requests
    pass


@app.on_event("shutdown")
async def shutdown_event():
    global hon_instance
    if hon_instance:
        await hon_instance.__aexit__(None, None, None)


async def get_hon():
    print(f"{datetime.now().isoformat()} get_hon() called")
    global hon_instance
    if hon_instance is None:
        return await init_hon()

    # Retry if access fails
    try:
        if not hon_instance.appliances:
            print("ℹ️ Reinitializing HON due to empty appliances list")
            return await init_hon()
        print(f"{datetime.now().isoformat()} returning hon_instance")
        return hon_instance
    except Exception as e:
        print("⚠️ Reinitializing HON due to error:", e)
        return await init_hon()


@app.get("/")
async def ac_status():
    async def html_stream():

        start_time = time.time()  # Start timer

        print(f"{datetime.now().isoformat()} New HTTP request, calling get_hon()...")

        #yield "<html><head><title>AC Status</title></head><body>\r\n"

        yield """<html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
        body { font-size: 16px; font-family: sans-serif; }
        .small { font-size: 12px; color: #666; }
        </style>
        <title>AC Status</title>
        </head><body>
        """
        yield "<h2>AC Devices</h2>\r\n"
        yield "<div id='login-hon'>\r\n"
        yield "<div>Logging in to HON...</div>\r\n"


        # Explicitly call get_hon to measure time
        #hon = await get_hon()  # Make sure get_hon is async

        #get_hon() with dot printing
        # Start get_hon() in background
        hon_task = asyncio.create_task(get_hon())

        yield "<div>\r\n"
        # While get_hon() is running, stream dots
        while not hon_task.done():
            yield ".\r\n"
            await asyncio.sleep(1)
        yield "</div>\r\n"

        # Get the result (or raise if error)
        hon = await hon_task

        yield "</div>\r\n"

        yield """
        <script>
            const loginhon = document.getElementById("login-hon");
            if (loginhon) loginhon.remove();
        </script>
        """
        
        # yield "<div class='small'>Fetching devices...</div>\r\n"

        device_id = 0
        
        for device in hon.appliances:
            try:
                device_id += 1
                yield f"<br /><b>{device.nick_name}</b>\r\n"
                yield f"<div id='getting-device-{device_id}'><p>Getting status...</p></div>\r\n"
                await device.update()

                yield f"""
                <script>
                    const device{device_id} = document.getElementById("getting-device-{device_id}");
                    if (device{device_id}) device{device_id}.remove();
                </script>
                """

                # Selected parameters
                temp = device.attributes["parameters"].get("tempIndoor")
                set_temp = device.attributes['parameters'].get('tempSel')
                onOffStatus = device.attributes['parameters'].get('onOffStatus')
                machMode = device.attributes['parameters'].get('machMode')
                timestampEvent = device.attributes['lastConnEvent'].get('timestampEvent')

                # when device is ON, "activity" {} is not empty
                # when device is OFF, "activity" {} is empty
                activity = device.attributes.get("activity", {})
                attrs = activity.get("attributes", {})

                # check if device is ON or OFF
                if attrs: 
                    yield f"<p><font color=blue>ON</font></p>\r\n"
                else:
                    yield f"<p>OFF</p>\r\n"

                # current indoor temperature (for both ON and OFF state)
                if temp:
                    yield f"<p>Indoor Temp: {temp.value}°C</p>\r\n"

                # print Set Temperature only when device is ON
                if set_temp:
                    if attrs:
                        if machMode.value != 6:
                            yield f"<p><font color=blue>Set Temperature: {set_temp.value}°C</font></p>\r\n"

                if set_temp:
                    if attrs:
                        if machMode.value != 6:
                            diff = float(temp.value) - float(set_temp.value)
                            yield f"<p>temp diff: {diff}</p>"

                mach_mode_map = {
                "0": "Auto",
                "1": "Cool",
                "2": "Dry",
                "3": "Fan",
                "4": "Heat",
                "5": "Eco",    # not always supported
                "6": "Fan",  # not always supported
                "7": "Sleep"   # rare
                }

                if machMode:
                    if attrs:
                        yield f"<p>Mode: {machMode.value} {mach_mode_map[str(machMode.value)]}</p>"

                if onOffStatus:
                    yield f"<div class='small'>onOffStatus: {onOffStatus.value}</div>\r\n"

                #if timestampEvent:
                #    # Your device event timestamp (in milliseconds)
                #    timestamp_ms = int(timestampEvent)
                #    # Convert to datetime (UTC)
                #    dt_utc = datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc)
                #    # Convert to local timezone
                #    local_tz = pytz.timezone("Europe/Warsaw")  # Replace with your local zone
                #    dt_local = dt_utc.astimezone(local_tz)
                #    # Format nicely
                #    formatted_datetime = dt_local.strftime("%Y-%m-%d %H:%M:%S")
                #    yield f"<div class='small'>Last connected (local time): {formatted_datetime}</div>"

            except Exception as e:
                yield f"error" + str(e)

        duration = time.time() - start_time
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        yield f"<br /><hr>\r\n"
        yield f"<p class='small'<i>{now}</i></p>\r\n"
        yield f"<p class='small'><i>Page generated in {duration:.2f} seconds</i></p>\r\n"
        yield "</body></html>"

    return StreamingResponse(html_stream(), media_type="text/html")
