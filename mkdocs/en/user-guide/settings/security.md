# Security

AssetFlow offers an optional app lock to protect your financial data from unauthorized access. When enabled, a full-screen overlay hides all portfolio data until you authenticate.

## Enabling App Lock

1. Open **Settings** (++cmd+comma++) and go to the **Security** section.
1. Toggle **Require Authentication** on.

![Security settings](../../assets/images/settings-security.png)

## Authentication Methods

The available authentication methods depend on your Mac's capabilities:

- **Touch ID** — available on MacBooks with a Touch ID sensor (MacBook Pro/Air with Touch Bar or later)
- **Apple Watch** — available if you have a paired Apple Watch
- **System password** — always available as a fallback on any Mac

## Timeout Settings

Control when AssetFlow locks itself with two independent timeout settings:

### When Switching Apps

How quickly the app locks after you switch away (e.g., ++cmd+tab++ to another app).

| Option          | Behavior                                      |
| --------------- | --------------------------------------------- |
| **Immediately** | Locks the moment you leave AssetFlow          |
| **1 Min**       | Locks after 1 minute away                     |
| **5 Min**       | Locks after 5 minutes away                    |
| **Never**       | Stays unlocked until your Mac sleeps or locks |

### When Locked or Sleeping

How quickly the app locks when your Mac's screen locks or enters sleep mode.

| Option          | Behavior                                    |
| --------------- | ------------------------------------------- |
| **Immediately** | Locks as soon as the screen locks or sleeps |
| **1 Min**       | Locks after 1 minute of screen lock/sleep   |
| **5 Min**       | Locks after 5 minutes of screen lock/sleep  |
| **Never**       | Stays unlocked even through sleep cycles    |

!!! tip

    Set "When Switching Apps" to "Never" if you frequently switch between AssetFlow and a spreadsheet while updating values.

## Lock Screen

When locked, a full-screen overlay completely hides all portfolio data. To unlock:

1. Click **Unlock** on the lock screen.
1. Authenticate using Touch ID, Apple Watch, or your system password.

The app automatically attempts to unlock when it becomes active, so in many cases you just need to look at your Touch ID sensor or tap your Apple Watch.

![Lock screen](../../assets/images/lock-screen.png)

!!! note

    When the app is locked, tooltips and hover effects are also hidden to prevent data leakage through the lock overlay.

## See also

- [Preferences](preferences.md): Customize display and import settings
- [Backup & Restore](backup-restore.md): Protect your data with regular backups
