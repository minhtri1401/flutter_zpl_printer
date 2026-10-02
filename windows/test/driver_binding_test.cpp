#include <gtest/gtest.h>

#include "../usb/driver_detector.h"

namespace flutter_zpl_printer {

TEST(ClassifyDriverService, MapsWinUsb) {
  EXPECT_EQ(ClassifyDriverService("winusb"), DriverBinding::kWinUsb);
  EXPECT_EQ(ClassifyDriverService("WinUSB"), DriverBinding::kWinUsb);
  EXPECT_EQ(ClassifyDriverService("WINUSB"), DriverBinding::kWinUsb);
}

TEST(ClassifyDriverService, MapsUsbPrint) {
  EXPECT_EQ(ClassifyDriverService("usbprint"), DriverBinding::kUsbPrint);
  EXPECT_EQ(ClassifyDriverService("UsbPrint"), DriverBinding::kUsbPrint);
}

TEST(ClassifyDriverService, OtherDriversMapToOther) {
  EXPECT_EQ(ClassifyDriverService(""), DriverBinding::kOther);
  EXPECT_EQ(ClassifyDriverService("libusbK"), DriverBinding::kOther);
  EXPECT_EQ(ClassifyDriverService("WinUSBK"), DriverBinding::kOther);
}

TEST(DriverBindingToString, RoundTrip) {
  EXPECT_EQ(DriverBindingToString(DriverBinding::kWinUsb), "WINUSB");
  EXPECT_EQ(DriverBindingToString(DriverBinding::kUsbPrint), "USBPRINT");
  EXPECT_EQ(DriverBindingToString(DriverBinding::kOther), "OTHER");
}

}  // namespace flutter_zpl_printer
