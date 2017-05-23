# odrive-copy
Recursive copy script for odrive to copy files from could to cloud.

## Usage Instructions (for Migrading from Amazon Cloud Drive)

In light of the recent banning of the open-source Amazon Drive clients by Amazon, the usage of `odcopy.sh` will be explained in the context of migrating from Amazon Cloud Drive to Google Drive.

0. [Grab the `odcopy.sh` script](https://raw.githubusercontent.com/interfect/odrive-copy/master/odcopy.sh) from this repository.

```
wget https://raw.githubusercontent.com/interfect/odrive-copy/master/odcopy.sh
chmod +x odcopy.sh
```

1. [Open an odrive account](https://www.odrive.com/login/start?redirectUrl=/login/websuccess) for free. None of the premium features are required.

2. Connect your cloud accounts: Amazon Cloud Drive and Google Drive. The names ytou assign to the accounts will be their paths in the folder used by odrive later.

3. [Download and start the odrive agent](https://docs.odrive.com/docs/odrive-sync-agent#section--download-sync-agent-), which is the proprietary odrive uploader/downloader process. It stays running as a server process.

4. [Download and install on your PATH the odrive.py CLI tool](https://docs.odrive.com/docs/odrive-cli#section--download-cli-), which is used to control the server.

5. [Create a new Authentication Code](https://www.odrive.com/account/authcodes) for your odrive account.

6. Authenticate your local client with odrive.

```
odrive.py authenticate YOUR-AUTH-CODE
```

7. Make a directory for odrive to keep files in. It only needs to have as much space as your largest file (plus placeholder files). Make sure it's on a filesystem that supports long paths (i.e. not an encrypted home directory).

```
mkdir /tmp/odrive
```

8. "Mount" your odrive. This isn't a real FUSE mount; it just tells odrive to synchronize stuff using this as a root.

```
odrive.py mount /tmp/odrive /
```

9. Sync (non-recursively) all the directories down to the ones you want to move. If you want to copy `Amazon Drive/data` to `Google Drive/data`, you would have to sync `Amazon Drive.cloudf` and `Google Drive.cloudf` in order to pull down placeholders for their immediate contents.

```
odrive.py sync /tmp/odrive/Amazon\ Drive.cloudf
odrive.py sync /tmp/odrive/Google\ Drive.cloudf
```

10. Start the copy operation. The source folder must exist and be unsynced (i.e. be a `.cloudf`). The destination folder may exist, but if it does it must also be unsynced.

```
./odcopy.sh /tmp/odrive/Amazon\ Drive/data.cloudf /tmp/odrive/Google\ Drive/data.cloudf
```

## Troubleshooting

The script won't start unless the folders you want to copy between are unsynced. If you abort the copy in the middle, or something goes wrong, you may need to manually unsync the folders:

```
odrive.py unsync /tmp/odrive/Amazon\ Drive/data.cloudf
odrive.py unsync /tmp/odrive/Google\ Drive/data.cloudf
```

## Contributing

There are many ways this script could be made more efficient or robust. Pull requests are gladly accepted.
