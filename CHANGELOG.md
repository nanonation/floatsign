# Change Log

## [2018-08-06]
### Changed
* Synchronized this script with the one in the Fastlane project: https://github.com/fastlane/fastlane/blob/master/sigh/lib/assets/resign.sh
### Added
* The -b flag can now be provided multiple times to rename multiple bundle identifiers. For example: `-b com.fnoex.fan.placeholder=com.example.fan -b com.fnoex.fan.notification-service=com.example.fan.notification-service`
