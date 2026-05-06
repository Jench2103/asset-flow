# Notifications

AssetFlow can send periodic local reminders so you don't forget to capture a fresh snapshot. Reminders are off by default — you opt in from Settings, and you can change the cadence or turn them off again at any time.

## Enabling Snapshot Reminders

1. Open **Settings** (++cmd+comma++) and go to the **Notifications** section.
1. Toggle **Snapshot Reminders** on.
1. macOS will ask for permission to send notifications the first time you enable this. Click **Allow** in the system prompt.

![Notifications settings](../../assets/images/settings-notifications.png)

If you previously denied notifications for AssetFlow in **System Settings → Notifications**, the toggle will revert and a "Notifications Disabled" alert will appear with an **Open System Settings** button. Enable notifications for AssetFlow there, then return to AssetFlow and try the toggle again.

## Choosing a Cadence

Once enabled, pick how often you want to be reminded:

| Frequency           | Configuration                                     |
| ------------------- | ------------------------------------------------- |
| **Daily**           | Choose a time of day                              |
| **Weekly**          | Choose a day of the week and a time               |
| **Every 2 Weeks**   | Choose a day of the week and a time               |
| **Monthly**         | Choose a day of the month (1–28) and a time       |
| **Custom Interval** | Choose any stride from 2 to 365 days, plus a time |

The day-of-month picker stops at 28 so the reminder fires consistently every month — no gaps in February or surprise jumps to the last day.

The Custom Interval mode is useful for cadences that don't line up with weekdays or month boundaries — for example, capturing a snapshot every 10 days. The first reminder fires at the next time-of-day after you save the setting, then every N days afterward.

![Notifications custom interval](../../assets/images/settings-notifications-custom-interval.png)

## What the Reminder Looks Like

When the reminder fires, you'll see a banner titled **AssetFlow Reminder** with the message _"Time to add a new portfolio snapshot."_ The banner contains no financial data, so it's safe to show on the lock screen.

The banner offers two actions:

- **Click the banner** — brings AssetFlow to the front and opens the New Snapshot sheet on the Snapshots screen, so you can pick the date and creation mode (empty, copy from latest, or bulk entry).
- **Remind Tomorrow** — schedules a one-shot reminder 24 hours later without disturbing the recurring schedule.

After the banner auto-dismisses, the reminder remains in macOS **Notification Center** until you clear it.

!!! tip

    If you want banners to stay on screen until you click them (rather than auto-dismissing after a few seconds), open **System Settings → Notifications → AssetFlow** and switch the alert style from **Banners** to **Alerts**. macOS controls this preference per app, so AssetFlow can't change it for you.

## Snoozing or Disabling

- To snooze just the next firing, click **Remind Tomorrow** on the banner.
- To pause reminders entirely, toggle **Snapshot Reminders** off in Settings. Any pending reminders are cleared immediately.
- To change the cadence, just adjust the pickers — AssetFlow re-applies the schedule automatically.

!!! note

    Reminders are scheduled by macOS itself, so they fire even when AssetFlow is closed. The schedule survives quitting the app, restarting your Mac, and putting it to sleep.

## See also

- [Preferences](preferences.md): Customize display and import settings
- [Security](security.md): Protect your data with app lock and authentication
- [Snapshots](../guide/snapshots.md): How to create and manage snapshots
- [Bulk Entry](../guide/bulk-entry.md): Enter values for multiple assets at once
