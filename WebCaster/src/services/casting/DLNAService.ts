import { CastDevice, DetectedVideo } from '../../models/types';

function buildSOAPEnvelope(body: string): string {
  return `<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>${body}</s:Body>
</s:Envelope>`;
}

function escapeXML(str: string): string {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function controlURL(device: CastDevice): string {
  if (device.controlURL) {
    if (device.controlURL.startsWith('http')) return device.controlURL;
    const path = device.controlURL.startsWith('/') ? device.controlURL : `/${device.controlURL}`;
    return `http://${device.host}:${device.port}${path}`;
  }
  return `http://${device.host}:${device.port}/AVTransport/Control`;
}

async function sendSOAP(device: CastDevice, action: string, body: string): Promise<boolean> {
  const url = controlURL(device);
  const serviceType = 'urn:schemas-upnp-org:service:AVTransport:1';
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPACTION': `"${serviceType}#${action}"`,
      },
      body: buildSOAPEnvelope(body),
    });
    return res.status === 200;
  } catch {
    return false;
  }
}

export const DLNA = {
  async cast(video: DetectedVideo, device: CastDevice): Promise<boolean> {
    const escapedURL = escapeXML(video.url);
    const escapedTitle = escapeXML(video.title);
    const didl = `&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;&lt;item id=&quot;0&quot; parentID=&quot;-1&quot; restricted=&quot;1&quot;&gt;&lt;dc:title&gt;${escapedTitle}&lt;/dc:title&gt;&lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;&lt;res protocolInfo=&quot;http-get:*:video/mp4:*&quot;&gt;${escapedURL}&lt;/res&gt;&lt;/item&gt;&lt;/DIDL-Lite&gt;`;

    const setURI = `<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>${escapedURL}</CurrentURI>
      <CurrentURIMetaData>${didl}</CurrentURIMetaData>
    </u:SetAVTransportURI>`;

    const ok = await sendSOAP(device, 'SetAVTransportURI', setURI);
    if (!ok) return false;
    return this.play(device);
  },

  async play(device: CastDevice): Promise<boolean> {
    return sendSOAP(device, 'Play', `<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>`);
  },

  async pause(device: CastDevice): Promise<boolean> {
    return sendSOAP(device, 'Pause', `<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:Pause>`);
  },

  async stop(device: CastDevice): Promise<boolean> {
    return sendSOAP(device, 'Stop', `<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:Stop>`);
  },

  async seek(device: CastDevice, position: string): Promise<boolean> {
    return sendSOAP(device, 'Seek', `<u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Unit>REL_TIME</Unit><Target>${position}</Target></u:Seek>`);
  },
};
