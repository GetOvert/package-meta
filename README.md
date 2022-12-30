# GetOvert/package-meta

Package metadata scraper tool for [Overt](https://getovert.app/).

This collects additional out-of-band information about packages, such as:

- App icons
- Publisher names / copyright notices
- Last updated/modified dates (derived from Git history)

All collected information is uploaded to Overt's public Google Cloud Storage bucket, and then downloaded selectively to users' machines by the [Overt app](https://github.com/GetOvert/Overt).

This metadata is collected a few times a day by the [GitHub Actions workflow](https://github.com/GetOvert/package-meta/actions/workflows/collect_and_upload.yml). Only packages that have been modified since the last run are re-processed.

## Opt out of icon collection

If you own the trademark or copyright for an app's icon and do not want it displayed in Overt, please [open an issue](https://github.com/GetOvert/package-meta/issues).

## Development

- Install Ruby; any recent version (2.7–3.2) should work fine
- `bundle install` to install dependencies
- Copy [.env.example](.env.example) to [.env](.env) and fill in your credentials for Google Cloud Storage

The scripts should now work locally; however, be aware that they will carelessly mess with your installed packages, and probably break your dev environment. For your own sake, use an isolated environment if possible.
