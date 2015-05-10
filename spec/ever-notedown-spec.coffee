EverNotedown = require '../lib/ever-notedown'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "EverNotedown", ->
  [workspaceElement, activationPromise] = []

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
    activationPromise = atom.packages.activatePackage('ever-notedown')

  describe "when the ever-notedown:toggle event is triggered", ->
    it "hides and shows the modal panel", ->
      # Before the activation event the view is not on the DOM, and no panel
      # has been created
      expect(workspaceElement.querySelector('.ever-notedown')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.commands.dispatch workspaceElement, 'ever-notedown:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(workspaceElement.querySelector('.ever-notedown')).toExist()

        everNotedownElement = workspaceElement.querySelector('.ever-notedown')
        expect(everNotedownElement).toExist()

        everNotedownPanel = atom.workspace.panelForItem(everNotedownElement)
        expect(everNotedownPanel.isVisible()).toBe true
        atom.commands.dispatch workspaceElement, 'ever-notedown:toggle'
        expect(everNotedownPanel.isVisible()).toBe false

    it "hides and shows the view", ->
      # This test shows you an integration test testing at the view level.

      # Attaching the workspaceElement to the DOM is required to allow the
      # `toBeVisible()` matchers to work. Anything testing visibility or focus
      # requires that the workspaceElement is on the DOM. Tests that attach the
      # workspaceElement to the DOM are generally slower than those off DOM.
      jasmine.attachToDOM(workspaceElement)

      expect(workspaceElement.querySelector('.ever-notedown')).not.toExist()

      # This is an activation event, triggering it causes the package to be
      # activated.
      atom.commands.dispatch workspaceElement, 'ever-notedown:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        # Now we can test for view visibility
        everNotedownElement = workspaceElement.querySelector('.ever-notedown')
        expect(everNotedownElement).toBeVisible()
        atom.commands.dispatch workspaceElement, 'ever-notedown:toggle'
        expect(everNotedownElement).not.toBeVisible()
