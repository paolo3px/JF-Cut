/**
 * COPYRIGHT NOTICE
 * Copyright (c) 2012, Institute of CG & CAD, Tsinghua University.
 * All Rights Reserved.
 * 
 * @file    *.cl
 * @brief   * functions definition.
 * 
 * This file defines *.
 * 
 * @version 1.0
 * @author  Jackie Pang
 * @e-mail  15pengyi@gmail.com
 * @date    2013/06/28
 */

constant sampler_t volumeSampler = CLK_NORMALIZED_COORDS_FALSE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_NEAREST;

#ifdef cl_image_2d

__kernel void graphcut_kmeans(
    const uint4 volumeSize, __read_only image2d_t volumeTexture,
    const uint cutOffset, __global cl_cut *cutData, __global int4* listData,
    const uint k, __global float4* centroidData, __global float4* sumData, __global int* countData,
    const float4 weight
    )
{
    const int2 tid = listData[get_global_id(2)].xy;
    const int2 lid = (int2)(get_global_id(0), get_global_id(1));
    const int2 gid = lid + (int2)(cl_block_2d_x, cl_block_2d_y) * tid;

    float4 data = (float4)(0.0f);
    int index = -1;
    if (gid.x < volumeSize.x && gid.y < volumeSize.y && ((__global char*)(cutData + gid.x + volumeSize.x * gid.y))[cutOffset] == CHAR_MAX)
    {
        data = read_imagef(volumeTexture, volumeSampler, gid) * weight;
        index = 0;
        
        float minDist = FLT_MAX;
        __global float4* centroid = centroidData + cutOffset * k;
        for (int i = 0; i < k; i++)
        {
            float d = distance(centroid[i], data);
            if (d < minDist)
            {
                minDist = d;
                index = i;
            }
        }
    }

    const int lid1D = lid.x + cl_block_2d_x * lid.y;
    __local float4 sumDatat[cl_block_2d_x * cl_block_2d_y];
    __local float4* sumt = sumDatat + lid1D;

    __local int countDatat[cl_block_2d_x * cl_block_2d_y];
    __local int* countt = countDatat + lid1D;

    __global float4* sum = sumData + get_global_id(2) * k;
    __global int* count = countData + get_global_id(2) * k;
    for (int i = 0; i < k; i++)
    {
        if (index == i)
        {
            *sumt = data;
            *countt = 1;
        }
        else
        {
            *sumt = (float4)(0.0f);
            *countt = 0;
        }
        
        for (int offset = cl_block_2d_x * cl_block_2d_y / 2; offset > 0; offset >>= 1)
        {
            barrier(CLK_LOCAL_MEM_FENCE);
            if (lid1D < offset)
            {
                *sumt += sumt[offset];
                *countt += countt[offset];
            }
        }
        if (lid1D == 0)
        {
            sum[i] = *sumt;
            count[i] = *countt;
        }
    };
}

#else

 __kernel void graphcut_kmeans(
    const uint4 volumeSize, __read_only image3d_t volumeTexture,
    const uint cutOffset, __global cl_cut *cutData, __global int4* listData,
    const uint k, __global float4* centroidData, __global float4* sumData, __global int* countData,
    const float4 weight
    )
{
    const int3 tid = listData[get_global_id(2)].xyz;
    const int3 lid = (int3)(get_global_id(0), get_global_id(1) % cl_block_3d_y, get_global_id(1) / cl_block_3d_y);
    const int3 gid = lid + (int3)(cl_block_3d_x, cl_block_3d_y, cl_block_3d_z) * tid;
    
    float4 data = (float4)(0.0f);
    int index = -1;
    if (gid.x < volumeSize.x && gid.y < volumeSize.y && gid.z < volumeSize.z && ((__global char*)(cutData + gid.x + volumeSize.x * (gid.y + volumeSize.y *gid.z)))[cutOffset] == CHAR_MAX)
    {
        data = read_imagef(volumeTexture, volumeSampler, (int4)(gid, 0)) * weight;
        float minDist = FLT_MAX;
        __global float4* centroid = centroidData + cutOffset * k;
        for (int i = 0; i < k; i++)
        {
            float d = distance(centroid[i], data);
            if (d < minDist)
            {
                minDist = d;
                index = i;
            }
        }
    }

    const int lid1D = lid.x + cl_block_3d_x * (lid.y + cl_block_3d_y * lid.z);
    __local float4 sumDatat[cl_block_3d_x * cl_block_3d_y * cl_block_3d_z];
    __local float4* sumt = sumDatat + lid1D;

    __local int countDatat[cl_block_3d_x * cl_block_3d_y * cl_block_3d_z];
    __local int* countt = countDatat + lid1D;

    __global float4* sum = sumData + get_global_id(2) * k;
    __global int* count = countData + get_global_id(2) * k;
    for (int i = 0; i < k; i++)
    {
        if (index == i)
        {
            *sumt = data;
            *countt = 1;
        }
        else
        {
            *sumt = (float4)(0.0f);
            *countt = 0;
        }

        for (int offset = cl_block_3d_x * cl_block_3d_y * cl_block_3d_z / 2; offset > 0; offset >>= 1)
        {
            barrier(CLK_LOCAL_MEM_FENCE);
            if (lid1D < offset)
            {
                *sumt += sumt[offset];
                *countt += countt[offset];
            }
        }
        if (lid1D == 0)
        {
            sum[i] = *sumt;
            count[i] = *countt;
        }
    };
}

#endif