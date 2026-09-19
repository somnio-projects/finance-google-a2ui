"""Release identity of the running process.

A deployed revision must be able to say *which build it is*. The packaged
``__version__`` cannot: it changes only when someone edits it, so a revision
that silently failed to update looks identical to one that succeeded. The
delivery pipeline therefore sets ``APP_RELEASE`` (spec 0007 AC-5), which
``Settings.app_release`` carries, and this resolves it.

Reading the environment is ``core/config.py``'s job
(``.claude/rules/backend/architecture.md``), so this function takes the
configured value rather than looking it up.
"""

from app import __version__


def resolve_release(configured: str) -> str:
    """Return the release identifier of this process.

    Args:
        configured: ``Settings.app_release`` — the value the delivery pipeline
            injected, or an empty string when nothing injected one.

    Returns:
        ``configured`` stripped, when it holds anything, otherwise the packaged
        ``__version__``. A blank value is treated as absent because an unset
        shell variable expands to an empty string, and an empty release
        identifier is worse than an honest default.
    """
    return configured.strip() or __version__


__all__ = ["resolve_release"]
