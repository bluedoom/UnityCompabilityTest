using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

public class EditorCode : IPreprocessBuildWithReport, IPostprocessBuildWithReport
{
    public int callbackOrder => 0;

    public void OnPostprocessBuild(BuildReport report)
    {
    }

    public void OnPreprocessBuild(BuildReport report)
    {
#if UNITY_OPENHARMONY
        PlayerSettings.OpenHarmony.blitType = OpenHarmonyBlitType.Never;
#endif
    }
}
