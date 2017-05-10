# cth_styledout

A Common Test hook that overrides the default output of Common Test on
stdout with a more concise and colored output.

## How to use

To use it with ct_run(1):

```
ct_run -ct_hooks cth_styledout
```

To use it with Erlang.mk:

```
make CT_OPTS='-ct_hooks cth_styledout'
```
