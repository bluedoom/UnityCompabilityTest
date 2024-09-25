// Pcx - Point cloud importer & renderer for Unity
// https://github.com/keijiro/Pcx

using UnityEngine;
using static Pcx.Triangle2Point;


namespace Pcx
{
    [UnityEditor.AssetImporters.ScriptedImporter(2, "pointcloud")]
    class PointCloudImporter : UnityEditor.AssetImporters.ScriptedImporter
    {
        public override void OnImportAsset(UnityEditor.AssetImporters.AssetImportContext context)
        {
            // Mesh container
            // Create a prefab with MeshFilter/MeshRenderer.
            var mesh = ImportAsMesh(context.assetPath);
            context.AddObjectToAsset("mesh", mesh);
            context.SetMainObject(mesh);
        }

        unsafe Mesh ImportAsMesh(string path)
        {
            using var arr = LoadAsNativeArray(path);
            return CreateMesh(arr,true);
        }
    }
}
