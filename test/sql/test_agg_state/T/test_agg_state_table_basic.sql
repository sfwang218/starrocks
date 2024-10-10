-- name: test_agg_state_table_basic
 CREATE TABLE `t1` ( 
    `k1`  date, 
    `k2`  datetime not null,
    `k3`  char(20), 
    `k4`  varchar(20) not null, 
    `k5`  boolean, 
    `k6`  tinyint not null, 
    `k7`  smallint, 
    `k8`  int not null, 
    `k9`  bigint, 
    `k10` largeint not null, 
    `k11` float, 
    `k12` double not null, 
    `k13` decimal(27,9)
) DUPLICATE KEY(`k1`, `k2`, `k3`, `k4`, `k5`) 
-- PARTITION BY date_trunc('day', %s) 
DISTRIBUTED BY HASH(`k1`, `k2`, `k3`) 
PROPERTIES (  "replication_num" = "1");
insert into t1  values('2020-01-01', '2020-01-01 10:10:10', 'aaaa', 'aaaa', 0, 1, 1, 1, 1, 1, 1.11, 11.111, 111.1111),('2020-02-01', '2020-02-01 10:10:10', 'bbbb', 'bbbb', 0, 2, 2, 2, 2, 2, 2.22, 22.222, 222.2222);

-- test for avg_state
CREATE TABLE test_agg_state_avg(
  k1 VARCHAR(10),
  k6 avg(tinyint),
  k7 avg(smallint),
  k8 avg(int),
  k9 avg(bigint),
  k10 avg(largeint),
  k11 avg(float),
  k12 avg(double),
  k13 avg(decimal(27, 9))
)
AGGREGATE KEY(k1)
PARTITION BY (k1) 
DISTRIBUTED BY HASH(k1) BUCKETS 3;
-- test for sum_state
CREATE TABLE test_agg_state_sum(
  k1 VARCHAR(10),
  k2 datetime,
  k6 sum(tinyint),
  k7 sum(smallint),
  k8 sum(int),
  k9 sum(bigint),
  k10 sum(largeint),
  k11 sum(float),
  k12 sum(double),
  k13 sum(decimal(27,9))
)
AGGREGATE KEY(k1, k2)
PARTITION BY (k1) 
DISTRIBUTED BY HASH(k1) BUCKETS 3;
-- test for min_state
CREATE TABLE test_agg_state_min(
  k1 VARCHAR(10),
  k6 min(tinyint),
  k7 min(smallint),
  k8 min(int),
  k9 min(bigint),
  k10 min(largeint),
  k11 min(float),
  k12 min(double),
  k13 min(decimal(27, 9))
)
AGGREGATE KEY(k1)
PARTITION BY (k1) 
DISTRIBUTED BY HASH(k1) BUCKETS 3;
-- test for min_by
CREATE TABLE test_agg_state_min_by(
  k1 VARCHAR(10),
  k6 min_by(tinyint, datetime),
  k7 min_by(smallint, datetime),
  k8 min_by(int, datetime),
  k9 min_by(bigint, datetime),
  k10 min_by(largeint, datetime),
  k11 min_by(float, datetime),
  k12 min_by(double, datetime),
  k13 min_by(decimal(27, 9), datetime)
)
AGGREGATE KEY(k1)
PARTITION BY (k1) 
DISTRIBUTED BY HASH(k1) BUCKETS 3;
-- first insert & test result
insert into test_agg_state_avg select k1, avg_state(k6), avg_state(k7), avg_state(k8), avg_state(k9), avg_state(k10), avg_state(k11), avg_state(k12), avg_state(k13) from t1;
insert into test_agg_state_sum select k1, k2, sum_state(k6), sum_state(k7), sum_state(k8), sum_state(k9), sum_state(k10), sum_state(k11), sum_state(k12), sum_state(k13) from t1;
insert into test_agg_state_min select k1, min_state(k6), min_state(k7), min_state(k8), min_state(k9), min_state(k10), min_state(k11), min_state(k12), min_state(k13) from t1;
insert into test_agg_state_min_by select k1, min_by_state(k6, k2), min_by_state(k7, k2), min_by_state(k8, k2), min_by_state(k9, k2), min_by_state(k10, k2), min_by_state(k11, k2), min_by_state(k12, k2), min_by_state(k13, k2) from t1;

-- query    
-- avg
select avg_merge(k6), avg_merge(k7), avg_merge(k8), avg_merge(k9), avg_merge(k10), avg_merge(k11), avg_merge(k12), avg_merge(k13) from test_agg_state_avg;
select k1,  avg_merge(k6), avg_merge(k7), avg_merge(k8), avg_merge(k9), avg_merge(k10), avg_merge(k11), avg_merge(k12), avg_merge(k13) from test_agg_state_avg group by 1 order by 1 limit 3;
-- sum
select sum_merge(k6), sum_merge(k7), sum_merge(k8), sum_merge(k9), sum_merge(k10), sum_merge(k11), sum_merge(k12), sum_merge(k13) from test_agg_state_sum;
select k1, sum_merge(k6), sum_merge(k7), sum_merge(k8), sum_merge(k9), sum_merge(k10), sum_merge(k11), sum_merge(k12), sum_merge(k13) from test_agg_state_sum group by k1 order by 1 limit 3;
-- min
select min_merge(k6), min_merge(k7), min_merge(k8), min_merge(k9), min_merge(k10), min_merge(k11), min_merge(k12), min_merge(k13) from test_agg_state_min;
select k1, min_merge(k6), min_merge(k7), min_merge(k8), min_merge(k9), min_merge(k10), min_merge(k11), min_merge(k12), min_merge(k13) from test_agg_state_min group by k1 order by 1 limit 3;
-- min_by
select min_by_merge(k6), min_by_merge(k7), min_by_merge(k8), min_by_merge(k9), min_by_merge(k10), min_by_merge(k11), min_by_merge(k12), min_by_merge(k13) from test_agg_state_min_by;
select k1, min_by_merge(k6), min_by_merge(k7), min_by_merge(k8), min_by_merge(k9), min_by_merge(k10), min_by_merge(k11), min_by_merge(k12), min_by_merge(k13) from test_agg_state_min_by group by k1 order by 1 limit 3;

-- second insert & test result
insert into t1  values('2020-01-02', '2020-01-01 10:10:10', 'aaaa', 'aaaa', 0, 1, 1, 1, 1, 1, 1.11, 11.111, 111.1111),('2020-02-01', '2020-02-01 10:10:10', 'bbbb', 'bbbb', 0, 2, 2, 2, 2, 2, 2.22, 22.222, 222.2222);
insert into test_agg_state_avg select k1, avg_state(k6), avg_state(k7), avg_state(k8), avg_state(k9), avg_state(k10), avg_state(k11), avg_state(k12), avg_state(k13) from t1;
insert into test_agg_state_avg select k1, avg_state(k6), avg_state(k7), avg_state(k8), avg_state(k9), avg_state(k10), avg_state(k11), avg_state(k12), avg_state(k13) from t1;
insert into test_agg_state_sum select k1, k2, sum_state(k6), sum_state(k7), sum_state(k8), sum_state(k9), sum_state(k10), sum_state(k11), sum_state(k12), sum_state(k13) from t1;
insert into test_agg_state_sum select k1, k2, sum_state(k6), sum_state(k7), sum_state(k8), sum_state(k9), sum_state(k10), sum_state(k11), sum_state(k12), sum_state(k13) from t1;
insert into test_agg_state_min select k1, min_state(k6), min_state(k7), min_state(k8), min_state(k9), min_state(k10), min_state(k11), min_state(k12), min_state(k13) from t1;
insert into test_agg_state_min select k1, min_state(k6), min_state(k7), min_state(k8), min_state(k9), min_state(k10), min_state(k11), min_state(k12), min_state(k13) from t1;
insert into test_agg_state_min_by select k1, min_by_state(k6, k2), min_by_state(k7, k2), min_by_state(k8, k2), min_by_state(k9, k2), min_by_state(k10, k2), min_by_state(k11, k2), min_by_state(k12, k2), min_by_state(k13, k2) from t1;
insert into test_agg_state_min_by select k1, min_by_state(k6, k2), min_by_state(k7, k2), min_by_state(k8, k2), min_by_state(k9, k2), min_by_state(k10, k2), min_by_state(k11, k2), min_by_state(k12, k2), min_by_state(k13, k2) from t1;
-- compact by hand
ALTER TABLE test_agg_state_sum COMPACT;
ALTER TABLE test_agg_state_avg COMPACT;
ALTER TABLE test_agg_state_min COMPACT;
ALTER TABLE test_agg_state_min_by COMPACT;
-- avg
select avg_merge(k6), avg_merge(k7), avg_merge(k8), avg_merge(k9), avg_merge(k10), avg_merge(k11), avg_merge(k12), avg_merge(k13) from test_agg_state_avg;
select k1, avg_merge(k6), avg_merge(k7), avg_merge(k8), avg_merge(k9), avg_merge(k10), avg_merge(k11), avg_merge(k12), avg_merge(k13) from test_agg_state_avg group by 1 order by 1 limit 3;
-- sum
select sum_merge(k6), sum_merge(k7), sum_merge(k8), sum_merge(k9), sum_merge(k10), sum_merge(k11), sum_merge(k12), sum_merge(k13) from test_agg_state_sum;
select k1, sum_merge(k6), sum_merge(k7), sum_merge(k8), sum_merge(k9), sum_merge(k10), sum_merge(k11), sum_merge(k12), sum_merge(k13) from test_agg_state_sum group by k1 order by 1 limit 3;
-- min
select min_merge(k6), min_merge(k7), min_merge(k8), min_merge(k9), min_merge(k10), min_merge(k11), min_merge(k12), min_merge(k13) from test_agg_state_min;
select k1, min_merge(k6), min_merge(k7), min_merge(k8), min_merge(k9), min_merge(k10), min_merge(k11), min_merge(k12), min_merge(k13) from test_agg_state_min group by k1 order by 1 limit 3;
-- min_by
select min_by_merge(k6), min_by_merge(k7), min_by_merge(k8), min_by_merge(k9), min_by_merge(k10), min_by_merge(k11), min_by_merge(k12), min_by_merge(k13) from test_agg_state_min_by;
select k1, min_by_merge(k6), min_by_merge(k7), min_by_merge(k8), min_by_merge(k9), min_by_merge(k10), min_by_merge(k11), min_by_merge(k12), min_by_merge(k13) from test_agg_state_min_by group by k1 order by 1 limit 3;
