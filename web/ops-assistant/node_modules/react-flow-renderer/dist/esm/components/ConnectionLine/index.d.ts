import { CSSProperties } from 'react';
import { ConnectionLineType, ConnectionLineComponent, HandleType } from '../../types';
declare type ConnectionLineProps = {
    connectionNodeId: string;
    connectionHandleType: HandleType;
    connectionLineType: ConnectionLineType;
    isConnectable: boolean;
    connectionLineStyle?: CSSProperties;
    CustomConnectionLineComponent?: ConnectionLineComponent;
};
declare const _default: ({ connectionNodeId, connectionHandleType, connectionLineStyle, connectionLineType, isConnectable, CustomConnectionLineComponent, }: ConnectionLineProps) => JSX.Element | null;
export default _default;
