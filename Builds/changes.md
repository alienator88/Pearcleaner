### What's New

- [x] Add manual install workaround for app store installd bug in 26.1 (Apple has blocked the private frameworks for MAS from being able to perform the install portion of the Update without private Apple entitlements. I haven't had a change to do a ton of QA on this workaround, so there could be some bugs. You can follow a more detailed discussion in the mas repo - https://github.com/mas-cli/mas/issues/1029)
- [x] Include Date Added resource key for sorting and app sidebar metadata - #432


### Fixes

- [x] Fix Deep search level with app that returns thousands of results - #440
- [x] Fix folder exclusion logic for apps - #433
- [x] Fix orphan search not finding results via username exclusion bug
- [x] Fix sensitivity slider per app not being respected - #434
- [x] Fix cask sizes not loading for some apps
- [x] Fix intermittent permissions bug - #436
- [x] Translations
