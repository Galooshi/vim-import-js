# Vim support

import-js is meant to be used as a Pathogen plugin. Just `git clone` this repo
into the `bundles` folder and you are good to go!

## Dependencies

You need to have the import-js npm package installed to use this plugin.

```sh
npm install -g import-js
```

## Default mappings

By default, import-js attempts to set up the following mappings:

Mapping     | Command               | Description
------------|-----------------------|---------------------------------------------------------------------
`<Leader>j` | `:ImportJSWord`       | Import the module for the variable under the cursor.
`<Leader>i` | `:ImportJSFix`        | Import any missing modules and remove any modules that are not used.
`<Leader>g` | `:ImportJSGoto`       | Go to the module of the variable under the cursor.
