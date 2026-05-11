from asyncio import create_subprocess_exec
from asyncio.subprocess import DEVNULL
from getpass import getuser
import logging
import os
import pwd
import sys

from ..enums import UserType

logger = logging.getLogger("localplatform")


def _get_user_id() -> int:
    return pwd.getpwnam(_get_user()).pw_uid


def _get_user() -> str:
    return get_unprivileged_user()


def _get_effective_user_id() -> int:
    return os.geteuid()


def _get_effective_user() -> str:
    return pwd.getpwuid(_get_effective_user_id()).pw_name


def _get_effective_user_group_id() -> int:
    return os.getegid()


def _get_user_owner(file_path: str) -> str:
    return pwd.getpwuid(os.stat(file_path).st_uid).pw_name


def _get_user_group_id() -> int:
    return pwd.getpwuid(_get_user_id()).pw_gid


def chown(path: str, user: UserType = UserType.HOST_USER, recursive: bool = True) -> bool:
    if _get_effective_user_id() != 0:
        return True

    user_id = _get_effective_user_id() if user == UserType.EFFECTIVE_USER else _get_user_id()
    group_id = _get_effective_user_group_id() if user == UserType.EFFECTIVE_USER else _get_user_group_id()

    try:
        if recursive:
            for root, dirs, files in os.walk(path):
                for directory in dirs:
                    os.chown(os.path.join(root, directory), user_id, group_id)
                for filename in files:
                    os.chown(os.path.join(root, filename), user_id, group_id)
        os.chown(path, user_id, group_id)
    except OSError as err:
        logger.warning("Failed to chown %s: %s", path, err)
        return False

    return True


def chmod(path: str, permissions: int, recursive: bool = True) -> bool:
    try:
        octal_permissions = int(str(permissions), 8)
        if recursive:
            for root, dirs, files in os.walk(path):
                for directory in dirs:
                    os.chmod(os.path.join(root, directory), octal_permissions)
                for filename in files:
                    os.chmod(os.path.join(root, filename), octal_permissions)
        os.chmod(path, octal_permissions)
    except OSError as err:
        logger.warning("Failed to chmod %s: %s", path, err)
        return False

    return True


def file_owner(path: str) -> UserType | None:
    user_owner = _get_user_owner(path)

    if user_owner == _get_user():
        return UserType.HOST_USER
    if user_owner == _get_effective_user():
        return UserType.EFFECTIVE_USER
    return None


def get_home_path(user: UserType = UserType.HOST_USER) -> str:
    user_name = _get_effective_user() if user == UserType.EFFECTIVE_USER else _get_user()
    return pwd.getpwnam(user_name).pw_dir


def setgid(user: UserType = UserType.HOST_USER):
    host_group_id = _get_user_group_id()
    effective_group_id = _get_effective_user_group_id()

    if host_group_id == effective_group_id:
        return
    if user == UserType.HOST_USER:
        os.setgid(host_group_id)
    elif user == UserType.EFFECTIVE_USER:
        os.setgid(effective_group_id)
    else:
        raise Exception("Unknown user type")


def setuid(user: UserType = UserType.HOST_USER):
    host_user_id = _get_user_id()
    effective_user_id = _get_effective_user_id()

    if host_user_id == effective_user_id:
        return
    if user == UserType.HOST_USER:
        os.setuid(host_user_id)
    elif user == UserType.EFFECTIVE_USER:
        os.setuid(effective_user_id)
    else:
        raise Exception("Unknown user type")


async def service_active(service_name: str) -> bool:
    return service_name == "plugin_loader"


async def service_stop(service_name: str) -> bool:
    return True


async def service_start(service_name: str) -> bool:
    return True


async def service_restart(service_name: str, block: bool = True) -> bool:
    if service_name == "plugin_loader":
        sys.exit(42)

    return True


def get_keep_systemd_service() -> bool:
    return True


def get_selinux() -> bool:
    return False


def get_effective_username() -> str:
    return _get_effective_user()


def get_username() -> str:
    return _get_user()


def get_privileged_path() -> str:
    return get_unprivileged_path()


def get_unprivileged_path() -> str:
    configured_path = os.getenv("UNPRIVILEGED_PATH") or os.getenv("PRIVILEGED_PATH")
    homebrew_path = configured_path or os.path.join(
        os.path.expanduser("~"),
        "Library",
        "Application Support",
        "decky-loader",
        "homebrew",
    )

    os.makedirs(homebrew_path, exist_ok=True)
    return homebrew_path


def get_unprivileged_user() -> str:
    return os.getenv("UNPRIVILEGED_USER", getuser())


def get_steam_root_path() -> str:
    return os.getenv(
        "STEAM_ROOT",
        os.path.join(os.path.expanduser("~"), "Library", "Application Support", "Steam"),
    )


def get_steam_executable_path() -> str:
    configured_path = os.getenv("STEAM_EXECUTABLE")
    if configured_path:
        return configured_path

    candidates = [
        os.path.join(get_steam_root_path(), "Steam.AppBundle", "Steam", "Contents", "MacOS", "steam_osx"),
        "/Applications/Steam.app/Contents/MacOS/steam_osx",
    ]

    for candidate in candidates:
        if os.path.exists(candidate):
            return candidate

    return candidates[0]


async def restart_webhelper() -> bool:
    logger.info("Restarting Steam Helper")
    process = await create_subprocess_exec("killall", "Steam Helper", stdout=DEVNULL, stderr=DEVNULL)
    return await process.wait() == 0


async def close_cef_socket():
    return
