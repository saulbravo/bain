#!/bin/sh
export PATH="$(pg_config --bindir):$PATH"
exec postgres -D /var/lib/postgresql/data
