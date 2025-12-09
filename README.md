Project [https://roadmap.sh/projects/automated-backups](https://roadmap.sh/projects/automated-backups)

1. Install AWS CLI
   
2. Add connection's config with R2
   ~/.aws/config Your url s3 bucket
   ```bash
   [profile r2-profi]
   region = auto
   endpoint_url = https://1cc24c979ef1f7b38b0b92e4a7d.r2.cloudflarestorage.com
   ```
   ~/.aws/credentials Two keys from bucket
   ```bash
   [profile r2-profi]
   aws_access_key_id = f76f68f7873aa9f2a1e42422f151
   aws_secret_access_key = 2299asdfb9ef708dlfsd89ae667307a740de55703630asdf9a999c5e1f9b
   ```
   
3. Start scrip, you should have active conrainer with mongodb, scrip connecting to localhost:27017 and do backup

4. Restore backup, taking last backup
   ```bash
   aws s3 cp s3://automated-backups/backups/all_dbs_20251208_232402.tar.gz . --profile r2-profi
   ```

5. Unarchive backup
   ```bash
   tar -xf all_dbs_20251208_232402.tar.gz -C ./restore
   ```
   
7. Start docker container
   ```bash
   docker compose -f ./docker-compose.yml up
   ```

8. Mongorestore also connecting to active container and do restore
   ```bash
   mongorestore --host localhost --port 27017 --drop ./restore
   ```
9. Cron task
    ```bash
    crontab -e

    insert:
    0 */12 * * * /opt/scripts/backup_mongo.sh >> /var/log/mongo_backup.log 2>&1
    ```
