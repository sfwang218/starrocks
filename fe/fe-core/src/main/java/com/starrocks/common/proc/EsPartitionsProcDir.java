// Copyright 2021-present StarRocks, Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// This file is based on code available under the Apache license here:
//   https://github.com/apache/incubator-doris/blob/master/fe/fe-core/src/main/java/org/apache/doris/common/proc/EsPartitionsProcDir.java

// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package com.starrocks.common.proc;

import com.google.common.base.Joiner;
import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import com.starrocks.catalog.Column;
import com.starrocks.catalog.Database;
import com.starrocks.catalog.EsTable;
import com.starrocks.catalog.PartitionType;
import com.starrocks.catalog.RangePartitionInfo;
import com.starrocks.catalog.Table.TableType;
import com.starrocks.common.AnalysisException;
import com.starrocks.common.util.concurrent.lock.LockType;
import com.starrocks.common.util.concurrent.lock.Locker;
import com.starrocks.connector.elasticsearch.EsShardPartitions;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/*
 * SHOW PROC /dbs/dbId/tableId/partitions
 * show partitions' detail info within a table
 */
public class EsPartitionsProcDir implements ProcDirInterface {
    public static final ImmutableList<String> TITLE_NAMES = new ImmutableList.Builder<String>()
            .add("IndexName").add("PartitionKey").add("Range").add("DistributionKey")
            .add("Shards").add("ReplicationNum")
            .build();

    public static final int PARTITION_NAME_INDEX = 1;

    private Database db;
    private EsTable esTable;

    public EsPartitionsProcDir(Database db, EsTable esTable) {
        this.db = db;
        this.esTable = esTable;
    }

    @Override
    public ProcResult fetchResult() throws AnalysisException {
        Preconditions.checkNotNull(db);
        Preconditions.checkNotNull(esTable);
        Preconditions.checkState(esTable.getType() == TableType.ELASTICSEARCH);

        // get info
        List<List<Comparable>> partitionInfos = new ArrayList<List<Comparable>>();
        Locker locker = new Locker();
        locker.lockDatabase(db.getId(), LockType.READ);
        try {
            Joiner joiner = Joiner.on(", ");
            Map<String, EsShardPartitions> unPartitionedIndices =
                    esTable.getEsTablePartitions().getUnPartitionedIndexStates();
            Map<String, EsShardPartitions> partitionedIndices =
                    esTable.getEsTablePartitions().getPartitionedIndexStates();
            for (EsShardPartitions esShardPartitions : unPartitionedIndices.values()) {
                List<Comparable> partitionInfo = new ArrayList<Comparable>();
                partitionInfo.add(esShardPartitions.getIndexName());
                partitionInfo.add("-");  // partition key
                partitionInfo.add("-");  // range
                partitionInfo.add("-");  // dis
                partitionInfo.add(esShardPartitions.getShardRoutings().size());  // shards
                partitionInfo.add(1);  //  replica num
                partitionInfos.add(partitionInfo);
            }

            RangePartitionInfo rangePartitionInfo = null;
            if (esTable.getPartitionInfo().getType() == PartitionType.RANGE) {
                rangePartitionInfo = (RangePartitionInfo) esTable.getEsTablePartitions().getPartitionInfo();
            }
            if (rangePartitionInfo != null) {
                for (EsShardPartitions esShardPartitions : partitionedIndices.values()) {
                    List<Comparable> partitionInfo = new ArrayList<Comparable>();
                    partitionInfo.add(esShardPartitions.getIndexName());
                    List<Column> partitionColumns = rangePartitionInfo.getPartitionColumns(esTable.getIdToColumn());
                    List<String> colNames = new ArrayList<String>();
                    for (Column column : partitionColumns) {
                        colNames.add(column.getName());
                    }
                    partitionInfo.add(joiner.join(colNames));  // partition key
                    partitionInfo.add(rangePartitionInfo.getRange(esShardPartitions.getPartitionId()).toString()); // range
                    partitionInfo.add("-");  // dis
                    partitionInfo.add(esShardPartitions.getShardRoutings().size());  // shards
                    partitionInfo.add(1);  //  replica num
                    partitionInfos.add(partitionInfo);
                }
            }
        } finally {
            locker.unLockDatabase(db.getId(), LockType.READ);
        }

        // set result
        BaseProcResult result = new BaseProcResult();
        result.setNames(TITLE_NAMES);
        for (List<Comparable> info : partitionInfos) {
            List<String> row = new ArrayList<String>(info.size());
            for (Comparable comparable : info) {
                row.add(comparable.toString());
            }
            result.addRow(row);
        }

        return result;
    }

    @Override
    public boolean register(String name, ProcNodeInterface node) {
        return false;
    }

    @Override
    public ProcNodeInterface lookup(String indexName) throws AnalysisException {

        Locker locker = new Locker();
        locker.lockDatabase(db.getId(), LockType.READ);
        try {
            return new EsShardProcDir(db, esTable, indexName);
        } finally {
            locker.unLockDatabase(db.getId(), LockType.READ);
        }
    }

}
