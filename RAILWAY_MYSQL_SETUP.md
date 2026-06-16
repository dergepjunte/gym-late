# Railway MySQL setup for GymLate

The app now uses MySQL automatically when `MYSQL_URL` is set. Without
`MYSQL_URL`, it falls back to the local SQLite database.

## Railway setup

1. Open your Railway project.
2. Click `+ New`.
3. Choose `Database`.
4. Choose `MySQL`.
5. Wait until the MySQL service is deployed.
6. Open your GymLate web service.
7. Go to `Variables`.
8. Add this variable:

```txt
MYSQL_URL=${{MySQL.MYSQL_URL}}
```

If your MySQL service has a different name, use that name instead of `MySQL`.
Railway's autocomplete in the variable editor can insert the correct reference.

9. Optional but recommended: add your own admin password.

```txt
ADMIN_PW=your-secure-password
```

10. Deploy the staged changes in Railway.

## Viewing the database

After deploy, open the MySQL service in Railway and use the database/table view.
The app creates these tables automatically on first boot:

- `groups`
- `users`
- `members`
- `entries`

## Existing SQLite data

This change does not automatically copy existing `data.db` rows into MySQL.
If you already have real production data in SQLite, download `data.db` from the
Railway volume first and migrate it before relying on the new MySQL database.

