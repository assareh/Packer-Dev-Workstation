# Using tmux for Persistent Claude Code Sessions

## Quick Start

When you SSH into your dev workstation, start a tmux session:

```bash
tmux new -s dev
```

Now you can run Claude Code:

```bash
claude
```

## Detaching and Reattaching

**To detach from tmux** (keeps Claude Code running):
- Press `Ctrl-a` then `d`

**To reattach to your session**:
```bash
tmux attach -t dev
```

**To list all sessions**:
```bash
tmux ls
```

## Common tmux Commands

All commands start with the prefix `Ctrl-a` (configured in .tmux.conf):

### Window Management
- `Ctrl-a c` - Create new window
- `Ctrl-a n` - Next window
- `Ctrl-a p` - Previous window
- `Ctrl-a 0-9` - Switch to window by number
- `Ctrl-a ,` - Rename current window

### Pane Management
- `Ctrl-a |` - Split pane vertically
- `Ctrl-a -` - Split pane horizontally
- `Ctrl-a h/j/k/l` - Navigate between panes (vim-style)
- `Ctrl-a x` - Kill current pane

### Session Management
- `Ctrl-a d` - Detach from session
- `Ctrl-a $` - Rename session
- `Ctrl-a s` - List and switch sessions

### Other Useful Commands
- `Ctrl-a r` - Reload tmux configuration
- `Ctrl-a ?` - Show all key bindings
- Mouse support is enabled - click to switch panes, scroll to navigate history

## Typical Workflow

1. SSH into your dev workstation from VS Code
2. Start or reattach to tmux: `tmux new -s dev` or `tmux attach -t dev`
3. Run Claude Code: `claude`
4. Work with Claude Code as normal
5. When done, detach: `Ctrl-a d`
6. Close VS Code - Claude Code keeps running!
7. Later, reconnect via VS Code Remote SSH
8. Reattach to tmux: `tmux attach -t dev`
9. Claude Code is still there, exactly where you left it

## Tips

- Create multiple windows in tmux for different tasks
- Use panes to have Claude Code running alongside other terminals
- tmux sessions persist even if your SSH connection drops
- All your work is automatically saved in tmux's scrollback buffer
