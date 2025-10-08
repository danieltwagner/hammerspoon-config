return {
    prevent_screen_sleep = true,
    ht_keywords = {
        ["/meet"] = "https://meet.google.com/<your-meet-url>",
        ["/date"] = function() return os.date("%Y-%m-%d") end,
        ["/time"] = function() return os.date("%H:%M:%S") end,
    }
}