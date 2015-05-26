#!/usr/bin/env python3
# -*- coding: utf-8 -*-

""" Randomly splits the users into two groups for tests.

    **Command-line parameters**

        *host*
            The host name.
        *database_name*
            The db.

    **Example of usage**

        ``python splitAB.py legiao.hypermindr.com:27017 api_production_20140630``

    **Output**

    Returns a JSON object as follows:
        {"success": "true"}, if the split operation ran fine;
        {"message": "some error message", "success": "false"}, otherwise.

    The script adds a "rollout" datetime attribute whose value is 0:00 of the current day.
    It does that to 50% randomly chosen users from the set of users whose "created_at" date
    is greater than the last time this script was run and less than two days ago.
"""

import json
import pymongo
import pytz
import sys
import traceback

import datetime as dt


def splitAB(database):
    from random import randint

    user_ids = fetch_users(database)
    n = len(user_ids)
    print("n_users = %d" % n)
    print("Running selection algorithm...")
    half = n // 2
    for k in range(half):
        idx = randint(k, n - 1)
        user_ids[k], user_ids[idx] = user_ids[idx], user_ids[k]
        if k % 1000 == 0:
            print("...%.2f%% done" % (100.0 * k / half))

    print("Saving to db...")
    select_for_rollout(database, user_ids[:half])

    return True


def fetch_users(database):
    cutoff_date = dt.datetime.now(pytz.utc) - dt.timedelta(days=2)
    where = {"created_at": {"$lt": cutoff_date}}

    cursor_rollout = database.users.find({"rollout": {"$ne": None}},
                                         ["rollout"]).sort([("rollout", -1)]).limit(1)
    if cursor_rollout is not None:
        last_rollout_date = cursor_rollout[0]["rollout"]
        where["created_at"].update({"$gt": last_rollout_date})

    cursor_users = database.users.find(where, ["external_id"])
    result = [u["external_id"] for u in cursor_users]
    return result


def select_for_rollout(database, user_ids):
    if len(user_ids) == 0:
        return
    bulk_op = database.users.initialize_unordered_bulk_op()
    for user_id in user_ids:
        bulk_op.find({"external_id": user_id}).update(
            {"$set": {"rollout": dt.datetime.now(pytz.utc).replace(hour=0, minute=0, second=0, microsecond=0)}})
    bulk_op.execute()


def main(argv):
    if len(argv) < 2:
        return json.dumps({"success": False,
                           "message": "You must specify the host and db"})
    try:
        # command-line arguments
        host_addr = argv[0]
        db_name = argv[1]
        database = pymongo.MongoClient(host_addr)[db_name]

        splitOK = splitAB(database)

    except Exception:
        return json.dumps({"success": False,
                           "message": traceback.format_exc()})

    if splitOK:
        return_json = json.dumps({"success": True})
        return return_json
    else:
        return json.dumps({"success": False})


if __name__ == '__main__':
    print(main(sys.argv[1:]))

