
using Assets;
using System;
using System.Collections;
using System.Text;
using TMPro;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.UI;

public class DisplayInfoPrinter : MonoBehaviour
{
    public TMPro.TextMeshProUGUI text;
    public TMPro.TextMeshProUGUI displayInfo;

    public Button btnResize;
    public Button btnClear;

    public Slider scale;

    // Start is called before the first frame update
    void Start()
    {
        if (text == null) text = GetComponentInChildren<TextMeshProUGUI>();
        if (btnResize == null) btnResize = GetComponentInChildren<Button>();
        if (btnClear == null) btnClear = GetComponentInChildren<Button>();
        if (scale == null) scale = GetComponentInChildren<Slider>();



        if (scale) scale.onValueChanged.AddListener(async s =>
        {
            curScale = s;
        });

    }

    // Update is called once per frame
    void Update()
    {
        if (text)
        {
            StringBuilder sb = new StringBuilder();
            sb.AppendLine($"scale: {curScale}, fps:{1 / Time.deltaTime:N1} | {Application.targetFrameRate} ");
            sb.AppendLine($"Screen.currentResolution : {Screen.currentResolution} \n\t w & h : {Screen.width} x {Screen.height}, dpi : {Screen.dpi}");
            var main = Display.main;
            sb.AppendLine($"Display.main || system: {main.systemWidth}x{main.systemHeight} \n\t render: {main.renderingWidth}x{main.renderingHeight}");
            var cMain = Camera.main;
            sb.AppendLine($"Camera|| pixel size: {cMain.pixelWidth}x{cMain.pixelHeight}");
            sb.AppendLine(benchResult);
            text.text = sb.ToString();
        }
        if (displayInfo)
        {


            StringBuilder sb = new();
            sb.AppendLine($"Device:  {SystemInfo.deviceName} || {SystemInfo.deviceModel}")
                .AppendLine("CPU: " + SystemInfo.processorType)
                .AppendLine($"   cout:{SystemInfo.processorCount}, freq: {SystemInfo.processorFrequency}")
                .AppendLine($"GPU: {SystemInfo.graphicsDeviceName}|{SystemInfo.graphicsDeviceID} ")
                //.AppendLine($"MEM: {SystemInfo}")
                ;

            sb.AppendLine("Screen.resolutions:\n");
            foreach (var size in Screen.resolutions)
            {
                sb.AppendLine(size.ToString());
            }
            displayInfo.text = sb.ToString();
        }
        SetSize2();
    }

    float curScale = 1;
    float _lastScale = 1;
    Vector2Int _lastRes;
    int level = 0;
    int lastLevel = -1;
    string benchResult = string.Empty;


    public void SetSize2()
    {
        var cur = Screen.currentResolution;
        var curRes = new Vector2Int(cur.width, cur.height);
        if (level != lastLevel || _lastRes != curRes)
        {
            var curScale = GetResolution(level);
            _lastRes = curRes;
            _lastScale = curScale;
            lastLevel = level;

            QualitySettings.resolutionScalingFixedDPIFactor = Mathf.Min(curScale, 1) * (Screen.dpi / 300);
            Debug.Log($"##Change res =>scale : {curScale:N1}, resolution:{Screen.currentResolution}");
        }
    }
    public void SetLevel()
    {
        level = (level < 3) ? level + 1 : 0;
        Debug.Log($"level{level}");
    }

    float GetResolution(int level)
    {
        var target = level switch
        {
            0 => new Vector2Int(1920, 1080),
            1 => new Vector2Int(1600, 900),
            2 => new Vector2Int(1280, 720),
            3 => new Vector2Int(960, 540),
            _ => new Vector2Int(1920, 1080),
        };

        var dpi = Screen.dpi;
        var curResolution = Screen.currentResolution;
        var curScale = 300 * QualitySettings.resolutionScalingFixedDPIFactor / dpi;
        var nativeW = curResolution.width / curScale;
        var nativeH = curResolution.height / curScale;
        Debug.Log($"Native Resolution:{nativeW} x {nativeH}");
        // 选取最近似的边作为调整基准
        if (nativeW / target.x > nativeH / target.y)
        {
            curScale = target.y / nativeH;
        }
        else
        {
            curScale = target.x / nativeW;
        }
        return curScale;
    }

    public void ChangeFrameRate()
    {
        var max = 0.0;
        foreach (var resolution in Screen.resolutions)
        {
            max = Math.Max(max, resolution.refreshRateRatio.value);
        }
        if (Application.targetFrameRate <= max && Application.targetFrameRate >= 15)
            Application.targetFrameRate += 5;
        else
            Application.targetFrameRate = 15;
    }

    public void SetSize(float scale)
    {
        Resolution max = new Resolution
        {
            height = 720,
            refreshRateRatio = new RefreshRate()
            {
                denominator = 1,
                numerator = 60,
            },
            width = 1920,
        };
        foreach (var size in Screen.resolutions)
        {
            if (size.width > max.width || size.height > max.height)
            {
                max = size;
            }
        }
        max.width = (int)(max.width * scale);
        max.height = (int)(max.height * scale);
        Screen.SetResolution(max.width, max.height, FullScreenMode.Windowed, max.refreshRateRatio);

        //Debug.Log("set to" + max);
    }

    public void ResetRes()
    {
        Screen.SetResolution(0, 0, true);
    }

    private void OnEnable()
    {
        Application.targetFrameRate = 999;
        StartCoroutine(RunBenchImpl());
    }

    public void RunBench()
    {
        StartCoroutine(RunBenchImpl());
    }
    IEnumerator RunBenchImpl()
    {
        for (int i = 0; i < 5; i++)
        {
            yield return new WaitForSeconds(1);
            Benchmarker.GetLevel(out var benchmarkResult, out var performanceLevel, out var socLevel);
            var benchB = Benchmarker.JustCPUBench(out var level, out _);
            benchResult += $"A: {benchmarkResult} ({performanceLevel}) || B: {benchB} ({level}) || soc match: {socLevel}\n";
        }
    }

}
