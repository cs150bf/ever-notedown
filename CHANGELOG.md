# CHANGELOG

## 0.2.13 - Bug fix
- Trying to fix issue https://github.com/cs150bf/ever-notedown/issues/23 and possibly https://github.com/cs150bf/ever-notedown/issues/20 ?
    - Steps to take:
        - Option 1:.Remove the package `ever-notedown` and do a clean re-install
        - Option 2. :
            1. Update `ever-notedown`
            2. In command line, `cd ~/.atom/packages/ever-notedown/`
            3. Run `apm clean`
            4. Run `apm install`

## 0.2.12 - Bug fix
- Fixed https://github.com/cs150bf/ever-notedown/issues/19

## 0.2.11, 0.2.10 - Improvement & revert
- Merged pull-request https://github.com/cs150bf/ever-notedown/pull/12 : Removed window message for successful operations
- Moving away from `window.alert` to `atom.notifications`
- Revert commit [4c26b53](https://github.com/cs150bf/ever-notedown/commit/4c26b530d96b) because the fix was problematic. See [#11](https://github.com/cs150bf/ever-notedown/issues/11) for details.

## 0.2.9 - Bug fix
- Trying to fix issue https://github.com/cs150bf/ever-notedown/issues/9 ("Syntax error, unrecognized expression" when html element id contains
special characters)

## 0.2.7 - Bug fix
- Fixed the confusion when two notes created on different days happen to have the same file name
- Fixed a typo (side panel)

## 0.2.6 - Bug fix
- Footnote rendering

## 0.2.5 - Bug fix (attempt)
- (Attempted) to fix issue https://github.com/cs150bf/ever-notedown/issues/7

## 0.2.4 - Bug fix (attempt)
- First step in fixing issue https://github.com/cs150bf/ever-notedown/issues/4
- Not sure about this...

## 0.2.3 - Bug fix (attempt)
- (Attempted) to fix issue https://github.com/cs150bf/ever-notedown/issues/3
- A rather basic patch... the functionality of writing notes in plain text or html is barely there and lacks testing

## 0.2.2 - Documentation
- Minor documentation updates (help document, notes for developers)
- Added CHANGELOG
- package.json now requires a newer version of Atom

## 0.2.1 - Bug fix (attempt)
- (Attempted) to fix issue https://github.com/cs150bf/ever-notedown/issues/2

## 0.2.0
- Picking up some updates from [markdown-preview](https://github.com/atom/markdown-preview)
- Resolve deprecations for Atom 1.0 API
- Minor code clean-up

## 0.1.2 - Documentation
- Minor documentation update

## 0.1.1 - Bug fix (attempt)
- (Attempted) to fix issue https://github.com/cs150bf/ever-notedown/issues/1

## 0.1.0 - First Release
- Release
