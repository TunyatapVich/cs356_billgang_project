type Broadcaster = (billId: string, message: unknown) => void;

let broadcaster: Broadcaster = () => {};

export const setBroadcaster = (fn: Broadcaster) => {
  broadcaster = fn;
};

export const broadcast = (billId: string, message: unknown) => {
  broadcaster(billId, message);
};
