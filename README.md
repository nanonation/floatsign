# floatsign.sh
=========

A bash script to re-sign iOS applications with Ad-Hoc or Enterprise distribution profile

## Usage
 
```bash
./floatsign source_file_name.ipa "iPhone Distribution: Name" -p "path/to/profile" [-d "display name"]  [-e entitlements] [-k keychain] -b "BundleIdentifier" output_filename.ipa
```

## History

`See floatsign.sh for original author and contributor information`

This script appears to have originated from [Float Mobile Learning](http://www.floatlearning.com/) in 2011, and has been been circulating around as a Gist, revised through by various commentors and re-gisted over the years.

We are posting our tweaked version of [this Gist](https://gist.github.com/Weptun/5406993) in this repository. Our initial changes were to add support for re-signing embedded iOS 8 frameworks, as well as incorporating a change to update the <key>com.apple.developer.team-identifier</key> in the entitlements as suggested in the comments of the referenced gist. 

Issues and pull requests with changes/fixes are welcomed.


## MIT License


Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
