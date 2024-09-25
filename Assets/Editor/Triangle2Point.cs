using UnityEngine;
using UnityEditor;
using Unity.Collections;
using UnityEngine.Rendering;
using Unity.Mathematics;
using System.Linq;
using System;
using System.Text;
using System.IO;
using Unity.Collections.LowLevel.Unsafe;

namespace Pcx
{
    public class Triangle2Point
    {
        ComputeShader _computeShader;
        Mesh _mesh;
        Mesh _output;
        [MenuItem("Assets/批处理/资源/转换三角Mesh为点云")]
        static void Convert()
        {
            var mesh = Selection.activeObject as Mesh;
            var compute = AssetDatabase.LoadAssetAtPath<ComputeShader>("TriToPointCloud.compute");
            var converter = new Triangle2Point() { _computeShader = compute, _mesh = mesh };
            var path = AssetDatabase.GetAssetPath(mesh);
            path = Path.Combine(Path.GetDirectoryName(path), Path.GetFileNameWithoutExtension(path));
            converter.ExportPointCloud(path);
        }

        public unsafe static NativeArray<VertexInfo> LoadAsNativeArray(string path)
        {
            var bytes = File.ReadAllBytes(path);
            var magic = bytes.AsSpan(0, VertexInfo.Magic.Length);
            if (magic.SequenceEqual(VertexInfo.Magic))
            {
                var size = sizeof(VertexInfo);

                var len = (bytes.Length - magic.Length) / size;
                if (len * size != bytes.Length - magic.Length)
                {
                    throw new Exception($"Size not multiple of {size} + {magic.Length}");
                }
                // Not safe for different architecture cpu.
                fixed (byte* p = bytes)
                {
                    var p2 = p + magic.Length;

                    var arr = NativeArrayUnsafeUtility.ConvertExistingDataToNativeArray<VertexInfo>(p2, len, Allocator.Temp);
                    NativeArrayUnsafeUtility.SetAtomicSafetyHandle(ref arr, AtomicSafetyHandle.Create());
                    return arr;
                }
                //VertexInfo[] arr = new VertexInfo[len];
                //var br = new BinaryReader(new MemoryStream(bytes, magic.Length, size * len));
                //for (int i = 0; i < arr.Length; i++)
                //{
                //    arr[i].pos.x = br.ReadSingle();
                //    arr[i].pos.y = br.ReadSingle();
                //    arr[i].pos.z = br.ReadSingle();

                //    arr[i].normal.x.value = br.ReadUInt16();
                //    arr[i].normal.y.value = br.ReadUInt16();
                //    arr[i].normal.z.value = br.ReadUInt16();
                //}
            }
            else
            {
                throw new Exception("Not a cloudpoint files");
            }
        }
        static void Export(string path, byte[] data)
        {
            path += ".pointcloud";

            using (var fs = File.Open(path, FileMode.Create, FileAccess.ReadWrite))
            {
                var w = new BinaryWriter(fs);
                w.Write(VertexInfo.Magic);
                w.Write(data);
                //for (int i = 0; i < nativeArr.Length; i++)
                //{
                //    var arr = nativeArr[i];
                //    w.Write(arr.pos.x);
                //    w.Write(arr.pos.y);
                //    w.Write(arr.pos.z);

                //    w.Write(arr.normal.x.value);
                //    w.Write(arr.normal.y.value);
                //    w.Write(arr.normal.z.value);
                //}
            }
        }

        private unsafe void ExportPointCloud(string path)
        {
            using (var nativeArr = GetNativeArray())
            {
                using (var data = nativeArr.Reinterpret<byte>(sizeof(VertexInfo)))
                {
                    Export(path, data.ToArray());
                }
            }
        }

        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        public struct VertexInfo
        {
            public float3 pos;
            public half4 normal;
            public static readonly byte[] Magic = Encoding.ASCII.GetBytes("POINT-CLOUD-V1");
            public static readonly VertexAttributeDescriptor[] layout = new VertexAttributeDescriptor[]
            {
                new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3),
                new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.Float16, 4),
            };
        }
        [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
        public struct LiteVertexInfo
        {
            public half4 pos;
            public half2 normal;
            public static readonly byte[] Magic = Encoding.ASCII.GetBytes("POINT-CLOUD-V1");
            public static readonly VertexAttributeDescriptor[] layout = new VertexAttributeDescriptor[]
            {
                new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float16, 4),
                new VertexAttributeDescriptor(VertexAttribute.Normal, VertexAttributeFormat.Float16, 2),
            };
        }

        private void ExportMesh(string path)
        {
            using (var nativeArr = GetNativeArray())
            {
                _output = CreateMesh(GetNativeArray());
                AssetDatabase.CreateAsset(_output, path + ".asset");
            }

        }

        public static Mesh CreateMesh(VertexInfo[] vInfo, bool compress = false)
        {
            using (var arr = new NativeArray<VertexInfo>(vInfo, Allocator.Temp))
            {
                return CreateMesh(arr, compress);
            }
        }

        public static Mesh CreateMesh(NativeArray<VertexInfo> newVertices, bool compress = false)
        {
            var m = new Mesh();
            if (compress)
            {
                m.SetVertexBufferParams(newVertices.Length, LiteVertexInfo.layout);
                NativeArray<LiteVertexInfo> lite = new NativeArray<LiteVertexInfo>(newVertices.Length, Allocator.Temp, NativeArrayOptions.UninitializedMemory);
                for (int i = 0; i < newVertices.Length; i++)
                {
                    var info = newVertices[i];
                    lite[i] = new LiteVertexInfo
                    {
                        pos = new half4((half3)info.pos, info.normal.x),
                        normal = info.normal.yz,
                    };
                }
                m.SetVertexBufferData(lite, 0, 0, newVertices.Length);
                lite.Dispose();
            }
            else
            {
                m.SetVertexBufferParams(newVertices.Length, VertexInfo.layout);
                m.SetVertexBufferData(newVertices, 0, 0, newVertices.Length);
            }
            var vCount = newVertices.Length;
            var indices = new int[vCount];
            Bounds b = new Bounds();
            for (int i = 0; i < vCount; i++)
            {
                indices[i] = i;
                b.Encapsulate(newVertices[i].pos);
            }
            m.indexFormat = indices.Length > ushort.MaxValue + 1 ? IndexFormat.UInt32 : IndexFormat.UInt16;
            m.SetIndices(indices, MeshTopology.Points, 0);
            m.bounds = b;

            return m;
        }

        NativeArray<VertexInfo> GetNativeArray()
        {
            var normals = _mesh.normals;
            var vertices = _mesh.vertices;
            var newVertices = new NativeArray<VertexInfo>(vertices.Length / 3, Allocator.Temp, NativeArrayOptions.UninitializedMemory);
            for (int i = 0; i < newVertices.Length; i++)
            {
                newVertices[i] = new VertexInfo
                {
                    pos = (vertices[i * 3]),
                    normal = new half4(new half3(normals[i * 3]), (half)0),
                };
            }
            return newVertices;
        }

        public void Compute()
        {
            //var kernel = _computeShader.FindKernel("Main");
            //ComputeBuffer cp = new ComputeBuffer();
            //_computeShader.SetBuffer(kernel, "SourceBuffer", sourceBuffer);
            //_computeShader.SetBuffer(kernel, "OutputBuffer", _pointBuffer);
            //_computeShader.Dispatch(kernel, sourceBuffer.count / 128, 1, 1);
        }
    }
}
