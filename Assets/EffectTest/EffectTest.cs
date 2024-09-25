using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NewBehaviourScript : MonoBehaviour
{
    public GameObject go;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        var time = Time.realtimeSinceStartup + 600; 
        Shader.SetGlobalFloat("_Tick", time);
        Shader.SetGlobalFloat("_TickMod", time%100);

        if(go)
        {
            go.transform.Rotate(new Vector3(1, 1, 1) * 1f);
        }

    }
}
