#include <math.h>
#include <stdlib.h>
#include <stdio.h>

#include <deque>
#include <pthread.h>

#include <gsl/gsl_randist.h>
#include <gsl/gsl_rng.h>

#include "util.h"

#define RECORD_SIZE 0x4000
#define MAX_SIZE 200

typedef struct {
  float noise[RECORD_SIZE];
} Record;


static void spawn_fillers();
static Record* fetch_record();

Complex gaussian_fast()
{
    static bool done_init = false;
    if (!done_init) {
        spawn_fillers();
        done_init = true;
    }

    static int i = 0;
    static Record* r = NULL;

    if (i == 0) {
        r = fetch_record();
    }

    Complex c = {
      rel: r->noise[i++],
      img: r->noise[i++]
    };

    if (i == RECORD_SIZE) {
        delete r;
        i = 0;
    }

    return c;
}


std::deque<Record*> records;
pthread_mutex_t r_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t  r_full_cond = PTHREAD_COND_INITIALIZER;

static const gsl_rng_type * T;
static gsl_rng* rnd()
{
  static __thread gsl_rng *r = NULL;
  if (r == NULL) {
    r = gsl_rng_alloc (gsl_rng_default);
  }
  return r;
}

static void add_record(Record* r)
{
    pthread_mutex_lock( &r_mutex );
    while (records.size() >= MAX_SIZE) {
        pthread_cond_wait( &r_full_cond, &r_mutex );
    }

    records.push_back(r);

    pthread_mutex_unlock( &r_mutex );
}

static Record* create_record()
{
    Record* r = new Record;
    for (int i = 0; i < RECORD_SIZE; i++) {
        r->noise[i] = gsl_ran_gaussian_ziggurat(rnd(), 1.0);
    }
    return r;
}

static Record* fetch_record()
{ 
    Record* record = NULL;
    pthread_mutex_lock( &r_mutex );
    if (records.size() > 0) {
        record = records.front();
        records.pop_front();
        pthread_cond_signal( &r_full_cond );
    }
    pthread_mutex_unlock( &r_mutex );

    if (record == NULL) {
        record = create_record();
    }

    return record;
}

static void init_rnd(int i)
{
    // set the seed to the i'th random number
    gsl_rng *rng = rnd();
    while (i-- > 0) gsl_rng_get(rng);
    gsl_rng_set(rng, gsl_rng_get(rng));
}

static void* fill_records(void *arg)
{
    // use a unique seed for each thread
    init_rnd((int) (long) arg);

    while (1) {
        Record* r = create_record();
        add_record(r);
    }
}

static void spawn_fillers()
{
    int THREADS = getenvi("CHANNEL_THREADS", 0);
    if (THREADS > 32) THREADS = 32;
    pthread_t thread[32];
    for (int i = 0; i < THREADS; i++) {
        int ret = pthread_create ( &thread[i], NULL, &fill_records, (void*) i );
        if (ret != 0) {
            printf("error creating thread: %d\n", ret);
            exit(1);
        }
    }
}
