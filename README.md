ImportJS helps you import JavaScript dependencies. Hit a keyboard shortcut
to automatically add `import x from 'y'` statements at the top of the file.

![Demo of ImportJS in action](https://raw.github.com/galooshi/vim-import-js/master/demo.gif)


# Installation

ImportJS is meant to be used as a Pathogen plugin. Just `git clone` this repo
into the `bundles` folder and you are good to go!
```
git clone git@github.com:Galooshi/vim-import-js.git ~/.vim/bundle/vim-import-js
```

## Dependencies

ImportJS works in [Vim](http://www.vim.org/) (version 8 and later) and
[Neovim](https://neovim.io/).

You need import-js installed globally to use this plugin.

```sh
npm install -g import-js
```

## Default mappings

By default, ImportJS attempts to set up the following mappings:

Mapping     | Command               | Description
------------|-----------------------|---------------------------------------------------------------------
`<Leader>j` | `:ImportJSWord`       | Import the module for the variable under the cursor.
`<Leader>i` | `:ImportJSFix`        | Import any missing modules and remove any modules that are not used.
`<Leader>g` | `:ImportJSGoto`       | Go to the module of the variable under the cursor.

## Configuration
For `import-js` configuration see https://github.com/Galooshi/import-js#configuration

## Troubleshooting

If you run into issues when using the plugin, adding some logging can help.
After starting up vim, and before you've imported anything, run this command:

```
:call ch_logfile('channel_log.txt', 'w')
```

After this, you should get useful information in `channel_log.txt`.
