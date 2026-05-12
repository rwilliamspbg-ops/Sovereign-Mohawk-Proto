import express from 'express';
import http from 'http';
export function createMockFederation(payload, port = 0) {
    const app = express();
    app.use(express.json());
    app.get('/api/v1/round/current', (_req, res) => {
        res.json({ data: payload });
    });
    const server = http.createServer(app);
    return new Promise((resolve, reject) => {
        server.listen(port, () => {
            // @ts-ignore
            const address = server.address();
            if (!address)
                return reject(new Error('Failed to bind mock federation server'));
            const actualPort = typeof address === 'string' ? 0 : address.port;
            const url = `http://127.0.0.1:${actualPort}`;
            resolve({
                url,
                close: () => new Promise((resClose) => server.close(() => resClose())),
            });
        });
    });
}
export default createMockFederation;
//# sourceMappingURL=mock-federation.js.map