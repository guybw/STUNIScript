# STUNIScript

This script was uploaded from https://www.reddit.com/r/SCCM/comments/m33wwc/stuni_script_improve_machine_performance_patching/ to help others and myself.

Improve Windows machine performance &amp; patching success

STUNI Script
Provides OS Inband Performance Tuneup for Windows Machine

Use to improve machine performance before patching and result in more quick & successful patching in a maintenance windows.

Functionality of this script :

Add Runtime Auditing
all actions logged to Event Log System, under Event Log Name STUNI and reported in final result STD output.

Run Check WMI Repository
for any Windows machine. Script will exit with error if this verification of the repository fails

Run DISM Image Cleanup
for Server 2012 and later machines.

Check for CleanMgr & Install if required
for Server 2008, Server 2008R2, Server 2012 and Server 2012R2 will automatically install binaries if not available.

Add CleanMgr Registry settings
for Server 2008 through to Server 2019, removes unnecessary files broadly across the machine

Run CleanMgr
for Server 2008 through to Server 2019.

Run cleanup ccmcache folder contents
for any SCCM Client installed machine.

Run Cleanup SoftwareDistribution folder
for any Windows machine.

Run Remove folder SoftwareDistribution.bak
for any Windows machine.

Run Remove folder SoftwareDistribution.old
for any Windows machine.

Run Optimize C drive storage
for any Windows machine.

Script designed to be signed and imported into SCCM, but may be run standalone.
