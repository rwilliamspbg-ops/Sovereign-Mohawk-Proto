import { MouseEvent as ReactMouseEvent } from 'react';
import { GetState, SetState } from 'zustand';
import { OnConnect, ConnectionMode, Connection, HandleType, ReactFlowState } from '../../types';
declare type ValidConnectionFunc = (connection: Connection) => boolean;
declare type Result = {
    elementBelow: Element | null;
    isValid: boolean;
    connection: Connection;
    isHoveringHandle: boolean;
};
export declare function checkElementBelowIsValid(event: MouseEvent, connectionMode: ConnectionMode, isTarget: boolean, nodeId: string, handleId: string | null, isValidConnection: ValidConnectionFunc, doc: Document | ShadowRoot): Result;
export declare function handleMouseDown({ event, handleId, nodeId, onConnect, isTarget, getState, setState, isValidConnection, elementEdgeUpdaterType, onEdgeUpdateEnd, }: {
    event: ReactMouseEvent;
    handleId: string | null;
    nodeId: string;
    onConnect: OnConnect;
    isTarget: boolean;
    getState: GetState<ReactFlowState>;
    setState: SetState<ReactFlowState>;
    isValidConnection: ValidConnectionFunc;
    elementEdgeUpdaterType?: HandleType;
    onEdgeUpdateEnd?: (evt: MouseEvent) => void;
}): void;
export {};
