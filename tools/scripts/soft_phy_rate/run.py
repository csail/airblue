#!/usr/bin/python

import os
import subprocess as s
import re
import sys

EXE = './soft_phy_rate_test_exe'

error_p = re.compile('errors:\s*(\d+)')
total_p = re.compile('total:\s*(\d+)')
sample_p = re.compile('sample:\s*(\d+)')
pred_p = re.compile('predicted:\s*(-?\d+.\d+)')

def main():
    sample = 0
    rate = 6

    while sample < 195000000:
        try:
            print '%9d rate=%d' % (sample, rate),
            res = run(sample, rate)
            best = find_best(sample, rate, res['errors'])

            print 'best=%d' % (best),

            print 'pred=%f' % (res['pred']),
            print 'errs=%d' % (res['errors']),

            if rate == best:
                print "OK"
            elif rate < best:
                print "UNDER"
            else:
                print "OVER"
            sys.stdout.flush()

            rate = choose_rate(rate, res['pred'])
            sample = res['sample']

        except Exception as e:
            print 'ERROR', e
            sample += 1000
            rate = 6

def find_best(sample, rate, errs):
    if errs == 0:
        for r in range(rate+2, 7, 2):
            res = run(sample, r)
            if res['errors'] != 0:
                return r - 2
        return 6
    else:
        for r in range(rate-2,-1,-2):
            res = run(sample, r)
            if res['errors'] == 0:
                return r
        return 0

def choose_rate(rate, pred):
    if rate == 0:
        if pred < -16:
            return 2
    if rate == 2:
        if pred > -12:
            return 0
        if pred < -63:
            return 4
    if rate == 4:
        if pred > -12:
            return 2
        if pred < -38:
            return 6
    if rate == 6:
        if pred > -9:
            return 4
    return rate

def run(sample, rate):
    env = os.environ.copy()
    env['CHANNEL_SAMPLE'] = str(sample)
    env['ADDERROR_RATE'] = str(rate)

    p = s.Popen([EXE],
            env=env, 
            stdout=s.PIPE,
            stderr=s.PIPE)
    p.wait()

    output = p.stdout.read()

    err=error_p.search(output).group(1)
    tot=total_p.search(output).group(1)
    samp=sample_p.search(output).group(1)
    pred=pred_p.search(output).group(1)

    return {
        'errors': int(err),
        'total': int(tot),
        'sample': int(samp),
        'pred': float(pred)
    }

if __name__ == '__main__':
    main()
