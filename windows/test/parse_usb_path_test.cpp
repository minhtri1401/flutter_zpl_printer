// Tests for ParseUsbPath. Pure function — no Windows SDK dependency beyond
// <string>, so these run on CI without requiring a real device.

#include <gtest/gtest.h>

#include "../usb/usb_path_parser.h"

namespace flutter_zpl_printer {

TEST(ParseUsbPath, ParsesVidPidSerial) {
  const auto r = ParseUsbPath(
      R"(\\?\USB#VID_0A5F&PID_0027#XXWFJ123#{a5dcbf10-6530-11d2-901f-00c04fb951ed})");
  ASSERT_TRUE(r.has_value());
  EXPECT_EQ(r->vendor_id, 0x0A5F);
  EXPECT_EQ(r->product_id, 0x0027);
  ASSERT_TRUE(r->serial.has_value());
  EXPECT_EQ(*r->serial, "XXWFJ123");
}

TEST(ParseUsbPath, HandlesLowerCaseHex) {
  const auto r = ParseUsbPath(R"(\\?\USB#vid_0a5f&pid_0027#ABC)");
  ASSERT_TRUE(r.has_value());
  EXPECT_EQ(r->vendor_id, 0x0A5F);
  EXPECT_EQ(r->product_id, 0x0027);
}

TEST(ParseUsbPath, ReturnsNulloptOnBadScheme) {
  EXPECT_FALSE(ParseUsbPath("C:/some/file").has_value());
  EXPECT_FALSE(ParseUsbPath(R"(\\?\HID#VID_0A5F&PID_0027)").has_value());
}

TEST(ParseUsbPath, ReturnsNulloptOnMissingPid) {
  EXPECT_FALSE(ParseUsbPath(R"(\\?\USB#VID_0A5F#SERIAL)").has_value());
}

TEST(ParseUsbPath, SkipsGuidLikeSerials) {
  const auto r = ParseUsbPath(
      R"(\\?\USB#VID_0A5F&PID_0027#{a5dcbf10-6530-11d2-901f-00c04fb951ed})");
  ASSERT_TRUE(r.has_value());
  EXPECT_FALSE(r->serial.has_value());
}

TEST(ParseUsbPath, ParsesWithoutSerialSegment) {
  const auto r = ParseUsbPath(R"(\\?\USB#VID_0A5F&PID_0027)");
  ASSERT_TRUE(r.has_value());
  EXPECT_EQ(r->vendor_id, 0x0A5F);
  EXPECT_FALSE(r->serial.has_value());
}

}  // namespace flutter_zpl_printer
