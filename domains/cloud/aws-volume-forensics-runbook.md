# AWS EBS Volume Forensics Runbook

Examine a suspect EBS volume without booting the instance it came from. Used for incident response (compromised host, suspicious activity) and data recovery. The core idea: never analyze a disk through the OS that might be compromised - detach it and read it from a clean host you control.

## Prerequisites

- A dedicated investigation EC2 instance (Linux) in the same availability zone as the suspect volume
- SSH key for the investigation host (e.g. `investigation-key.pem`)
- IAM permissions: `ec2:DescribeVolumes`, `ec2:CreateSnapshot`, `ec2:AttachVolume`, `ec2:DetachVolume`
- Keep the investigation instance stopped when not in use - start it per investigation, stop it after

## Runbook

### 1. Snapshot first

Before touching the volume, snapshot it. This preserves the original state as evidence and gives you a rollback point if anything goes wrong during examination.

```bash
aws ec2 create-snapshot --volume-id vol-xxxxxxxxxxxxx \
  --description "Forensic preservation - case YYYY-NNN - pre-examination"
```

Wait for the snapshot to complete before proceeding.

### 2. Start the investigation host

```bash
aws ec2 start-instances --instance-ids i-xxxxxxxxxxxxx
```

Confirm it is in the same AZ as the volume (`aws ec2 describe-volumes --volume-ids vol-xxx --query 'Volumes[0].AvailabilityZone'`). EBS volumes only attach within their AZ - if they differ, create a volume from the snapshot in the investigation host's AZ instead.

### 3. Detach the suspect volume from its original instance

If the volume is still attached to the suspect instance, stop that instance first (do not terminate - you may need it later), then detach:

```bash
aws ec2 detach-volume --volume-id vol-xxxxxxxxxxxxx
```

### 4. Attach to the investigation host

```bash
aws ec2 attach-volume --volume-id vol-xxxxxxxxxxxxx \
  --instance-id i-xxxxxxxxxxxxx --device /dev/sdf
```

### 5. SSH in and identify the device

```bash
ssh -i "investigation-key.pem" ec2-user@10.0.1.20
lsblk
sudo fdisk -l
```

Note: the device name you requested (`/dev/sdf`) usually appears as `/dev/xvdf` or `/dev/nvme1n1` depending on instance type. `lsblk` shows the partitions - a typical volume shows as `xvdf` with partition `xvdf1`.

### 6. Mount read-only

```bash
sudo mkdir -p /mnt/investigation
sudo mount -o ro,noexec,nosuid,nodev /dev/xvdf1 /mnt/investigation
```

Verify: `mount | grep investigation` should show `(ro,...)`.

### 7. Examine

Work from `/mnt/investigation`. Typical checks:

```bash
# Recently modified files (last 7 days)
sudo find /mnt/investigation -type f -mtime -7 -ls

# Shell histories, cron, ssh keys, persistence locations
sudo cat /mnt/investigation/home/*/.bash_history
sudo ls -la /mnt/investigation/etc/cron.d/ /mnt/investigation/var/spool/cron/
sudo cat /mnt/investigation/home/*/.ssh/authorized_keys

# Auth and system logs
sudo less /mnt/investigation/var/log/auth.log
sudo less /mnt/investigation/var/log/syslog
```

Copy anything of evidentiary value off the volume (to your case folder), never edit in place.

### 8. Unmount

```bash
sudo umount /mnt/investigation
```

### 9. Detach and disposition

```bash
aws ec2 detach-volume --volume-id vol-xxxxxxxxxxxxx
```

Then either reattach to the original instance (recovery case), keep it detached pending case closure (incident case), or delete it once the snapshot is confirmed as the retained evidence copy.

### 10. Document

Record in the case notes: volume ID, snapshot ID, attach/detach timestamps, commands run, findings, and files extracted. Stop the investigation instance.

## Why read-only mount matters

Three reasons:

1. **Evidence integrity** - a normal (rw) mount updates filesystem metadata the moment it mounts: journal replay, access times, superblock writes. That alters the evidence before you have looked at a single file. `ro` plus the pre-examination snapshot gives you a defensible chain: the snapshot is the pristine copy, the ro mount proves the working copy was not modified during analysis.
2. **Self-protection** - `noexec,nosuid,nodev` prevent anything on the suspect disk from executing on your investigation host. A compromised volume can contain setuid binaries or device nodes planted exactly for the moment someone mounts it.
3. **No accidental damage** - you cannot fat-finger a delete or overwrite on a read-only filesystem.

If the filesystem refuses to mount ro due to a dirty journal (common with XFS/ext4 from a crashed host), use `-o ro,norecovery` (XFS) or `-o ro,noload` (ext4) rather than letting the mount replay the journal - and work from a fresh volume created off the snapshot if in doubt.
