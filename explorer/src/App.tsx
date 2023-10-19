import { useState } from "react";
import veraxLogo from "./assets/verax-logo-circle.svg";
import "./App.css";

function App() {
  const [attestations, setAttestations] = useState<Attestation[]>([]);

  const getSomeAttestations = async () => {
    const veraxSdk = new VeraxSdk(VeraxSdk.DEFAULT_LINEA_TESTNET_FRONTEND);
    setAttestations(await veraxSdk.attestation.findBy(2));
  };

  return (
    <>
      <div>
        <a href="https://verax.gitbook.io/verax/" target="_blank">
          <img src={veraxLogo} className="logo" alt="Verax logo" />
        </a>
      </div>
      <h1>Verax Attestation Registry</h1>
      <div className="card">
        <button onClick={getSomeAttestations}>Get some attestations</button>
        {attestations.length > 0 && (
          <ul>
            {attestations.map((attestation) => (
              <li key={attestation.id}>{attestation.id}</li>
            ))}
          </ul>
        )}
      </div>
      <p className="read-the-docs">Click on the Verax logo to learn more</p>
    </>
  );
}

export default App;
