# KiroOS OTA extensions for the Galaxy S6 family (universal7420-common).
#
# The S6 flat full package flashes the KiroOS boot logo ("Samsung Powered by KiroDev") on
# the PARAM partition. The image travels in the package as install/param.bin
# (PRODUCT_COPY_FILES in zerofltexx/device.mk -> $OUT/install -> target-files INSTALL/ ->
# OTA install/), so nothing has to repack or re-sign the zip after the build.
#
# PARAM holds model specific bootloader images: the S6 edge / edge+ never get it, both
# because their builds carry no param.bin and because of the device check below.

PARAM_DEVICE = "/dev/block/platform/15570000.ufs/by-name/PARAM"
PARAM_MODELS = ("zerofltexx",)


def FullOTA_InstallEnd(info):
  if "INSTALL/param.bin" not in info.input_zip.namelist():
    return
  device = info.info_dict.get("build.prop", {}).get("ro.cm.device", "")
  if device not in PARAM_MODELS:
    print("KiroOS: skipping param.bin for %s" % device)
    return
  info.script.Print("Aggiornamento Boot Logo Samsung Powered by KiroDev...")
  info.script.AppendExtra('package_extract_file("install/param.bin", "%s");'
                          % PARAM_DEVICE)
