#!/bin/sh -e

/app/bin/appdashboard eval "AppDashboard.Release.migrate"

exec /app/bin/appdashboard start
