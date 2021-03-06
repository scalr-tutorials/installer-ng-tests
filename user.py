#!/usr/bin/env python
import sys
import json
import datetime
import base64

from scalr_client import session


TEST_USER_NAME = "Test User"
TEST_USER_EMAIL = "user@scalr.com"
TEST_USER_PASSWORD_ENTROPY_BYTES = 24


def make_test_user_password(n_entropy):
    with open('/dev/urandom') as f:
        return base64.b64encode(f.read(n_entropy))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print "Usage: user.py <config-file>"
        sys.exit(1)

    config_file = sys.argv[1]

    with open(config_file) as f:
        installer_config = json.load(f)

    base_url = "{0}://{1}".format(
            installer_config["scalr"]["endpoint"]["scheme"],
            installer_config["scalr"]["endpoint"]["host"]
    )

    # Find admin creds
    admin = installer_config["scalr"]["admin"]
    admin_username = admin["username"]
    admin_password = admin["password"]

    # Login as admin
    adm_session = session.ScalrSession(base_url=base_url)
    adm_session.login(admin_username, admin_password)

    # Create a new user
    test_user_password = make_test_user_password(TEST_USER_PASSWORD_ENTROPY_BYTES)
    res = adm_session.create_account(TEST_USER_NAME, TEST_USER_EMAIL, test_user_password)
    test_user_id = res.json()["accountId"]

    # Login as the user
    user_session = session.ScalrSession(base_url=base_url)
    user_session.login(TEST_USER_EMAIL, test_user_password, test_user_id)

    # Do something
    print user_session.get_ec2_cloud_params().json()

