import argparse
import sys

from utils import str2bool, str2list, str2map
from hub import Hub
from mirror import Mirror


class HubMirror(object):
    def __init__(self):
        self.parser = self._create_parser()
        self.args = self.parser.parse_args()
        self.white_list = str2list(self.args.white_list)
        self.black_list = str2list(self.args.black_list)
        self.static_list = str2list(self.args.static_list)
        self.mappings = str2map(self.args.mappings)

    def _create_parser(self):
        parser = argparse.ArgumentParser(
            description="Mirror the organization repos between hub (gitea/github/gitee/gitLab)."
        )
        # Add arguments with default values and descriptions
        parser.add_argument("--dst-key", type=str, required=True, help="The private SSH key used to push code in the destination hub.")
        parser.add_argument("--dst-token", type=str, required=True, help="The app token used to create repos in the destination hub.")
        parser.add_argument("--dst", type=str, required=True, help="Destination name. Such as `gitee/kunpengcompute`.")
        parser.add_argument("--gitea-url", type=str, default="", help="The base URL for your Gitea instance, e.g., `https://your.gitea.instance`.")
        parser.add_argument("--src", type=str, required=True, help="Source name. Such as `github/kunpengcompute`.")
        parser.add_argument("--account-type", type=str, default="user", help="The account type. Such as org, user, group.")
        parser.add_argument("--src-account-type", type=str, default="", help="The src account type. Such as org, user, group.")
        parser.add_argument("--dst-account-type", type=str, default="", help="The dst account type. Such as org, user, group.")
        parser.add_argument("--clone-style", type=str, default="https", help="The git clone style, https or ssh.")
        parser.add_argument("--cache-path", type=str, default="/github/workspace/hub-mirror-cache", help="The path to cache the source repos code.")
        parser.add_argument("--black-list", type=str, default="", help="High priority, the blacklist of mirror repos, separated by commas.")
        parser.add_argument("--white-list", type=str, default="", help="Low priority, the whitelist of mirror repos, separated by commas.")
        parser.add_argument("--static-list", type=str, default="", help="Only mirror repos in the static list, separated by commas.")
        parser.add_argument("--force-update", type=str2bool, default=False, help="Force to update the destination repo, use '-f' flag for 'git push'.")
        parser.add_argument("--debug", type=str2bool, default=False, help="Enable the debug flag to show detailed log.")
        parser.add_argument("--timeout", type=str, default="30m", help="Set the timeout for every git command, e.g., '600'=600s, '30m'=30 mins.")
        parser.add_argument("--api-timeout", type=int, default=60, help="Set the timeout for API requests (in seconds).")
        parser.add_argument("--mappings", type=str, default="", help="The source repos mappings, e.g., 'A=>B, C=>CC'. Source repo name would be mapped accordingly.")
        parser.add_argument("--lfs", type=str2bool, default=False, help="Enable Git LFS support.")
        return parser

    def test_black_white_list(self, repo):
        if repo in self.black_list:
            print(f"Skip, {repo} in black list: {self.black_list}")
            return False

        if self.white_list and repo not in self.white_list:
            print(f"Skip, {repo} not in white list: {self.white_list}")
            return False

        return True

    def run(self):
        hub = Hub(
            self.args.src,
            self.args.dst,
            self.args.dst_token,
            account_type=self.args.account_type,
            clone_style=self.args.clone_style,
            src_account_type=self.args.src_account_type,
            dst_account_type=self.args.dst_account_type,
            api_timeout=int(self.args.api_timeout),
            gitea_url=self.args.gitea_url
        )
        src_type, src_account = self.args.src.split('/')

        # Using static list when static_list is set
        repos = self.static_list
        src_repos = repos if repos else hub.dynamic_list()

        total, success, skip = len(src_repos), 0, 0
        failed_list = []
        for src_repo in src_repos:
            # Set dst_repo to src_repo mapping or src_repo directly
            dst_repo = self.mappings.get(src_repo, src_repo)
            print(f"Map {src_repo} to {dst_repo}")
            if self.test_black_white_list(src_repo):
                print(f"Backup {src_repo}")
                try:
                    mirror = Mirror(
                        hub, src_repo, dst_repo,
                        cache=self.args.cache_path,
                        timeout=self.args.timeout,
                        force_update=self.args.force_update,
                        lfs=(
                            self.args.lfs if hasattr(self.args, "lfs")
                            else False
                        )
                    )
                    mirror.download()
                    mirror.create()
                    mirror.push()
                    success += 1
                except Exception as e:
                    print(e)
                    failed_list.append(src_repo)
            else:
                skip += 1
        failed = total - success - skip
        res = (total, skip, success, failed)
        print(f"Total: {total}, skip: {skip}, successed: {success}, failed: {failed}.")
        print(f"Failed: {failed_list}")
        if failed_list:
            sys.exit(1)


if __name__ == '__main__':
    mirror = HubMirror()
    mirror.run()
